require 'yaml'

objects = YAML.load_stream(File.read(ARGV.fetch(0))).compact
services = objects.select { |object| object['kind'] == 'Service' }
front = services.find { |service| service.dig('metadata', 'name') == 'frontend' }
abort 'Missing internal frontend' unless front&.dig('spec', 'type') == 'ClusterIP'
abort 'Unexpected public service' if services.any? { |service|
  spec = service.fetch('spec')
  %w[NodePort LoadBalancer].include?(spec['type']) || spec.fetch('externalIPs', []).any?
}
abort 'Signing or other Secret present in rendered manifests' if objects.any? { |object| object['kind'] == 'Secret' }

workloads = objects.select { |object| %w[Deployment StatefulSet].include?(object['kind']) }
abort 'Missing workloads' if workloads.size < 9
workloads.each do |workload|
  name = workload.dig('metadata', 'name')
  spec = workload.fetch('spec')
  abort "Service-account token mounts in #{name}" unless spec.dig('template', 'spec', 'automountServiceAccountToken') == false
  abort 'Load generator enabled' if name == 'loadgenerator' && spec['replicas'] != 0
  spec.dig('template', 'spec', 'containers').each do |container|
    container.fetch('env', []).each do |variable|
      next unless %w[ENABLE_TRACING ENABLE_METRICS].include?(variable['name'])
      abort "Cloud telemetry enabled in #{name}" unless variable['value'] == 'false'
    end
    abort "Unpinned image in #{name}" unless container.fetch('image').match?(/@sha256:[a-f0-9]{64}\z/)
  end
end

abort 'Upstream cloud identity binding present' if objects.any? { |object|
  object.dig('metadata', 'annotations', 'iam.gke.io/gcp-service-account')
}
expected = %w[deny-ingress allow-frontend allow-application-apis allow-accounts-db allow-ledger-db]
policies = objects.select { |object| object['kind'] == 'NetworkPolicy' }
abort 'Missing ingress policies' unless (expected - policies.map { |policy| policy.dig('metadata', 'name') }).empty?
