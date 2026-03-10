# Validación de Vulnerabilidad en Quarkus con Snyk

```bash
# Instalar Snyk CLI
npm install -g snyk

# Autenticar (necesitas cuenta gratuita)
snyk auth

# Verificar vulnerabilidades
snyk test
```

# Error certificado tls
```bash
openssl s_client -connect api.snyk.io:443 -proxy 10.16.32.53:3128 -showcerts </dev/null 2>/dev/null | openssl x509 -outform PEM > /tmp/proxy-cert.pem
 
sudo cp /tmp/proxy-cert.pem /usr/local/share/ca-certificates/proxy-cert.crt
sudo update-ca-certificates

# Validar certificado
curl -x http://10.16.32.53:3128 https://api.snyk.io/v1/
```