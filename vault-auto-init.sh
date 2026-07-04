# infraestructura/vault-auto-init.sh
# Ejecutado automáticamente por el servicio "vault-init" del docker-compose,
# una vez que el healthcheck de "vault" pasa a healthy. No usar docker exec
# aquí: este script corre dentro de un contenedor con el binario vault propio,
# hablando con Vault por red (VAULT_ADDR=http://vault:8200).

echo "Habilitando motor Transit (si no existe)..."
vault secrets enable transit || echo "Transit ya estaba habilitado, se continúa."

echo "Creando/verificando llave clickloker-key..."
vault write -f transit/keys/clickloker-key

echo "Creando/verificando llave plataforma-key..."
vault write -f transit/keys/plataforma-key

echo "Vault listo."
