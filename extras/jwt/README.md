# JWT signing Secret

Use fresh signing material for each deployment. The portfolio installation commands in the root README create the Secret directly. Legacy examples that expect a local file can generate it with Bash:

~~~sh
umask 077
bash scripts/generate-jwt-secret.sh > extras/jwt/jwt-secret.yaml
~~~

Keep this file local and remove it when it is no longer needed.
