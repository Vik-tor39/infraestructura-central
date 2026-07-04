# infraestructura/init-vault.sh
#
# NOTA: "docker compose up" ya dispara esto automáticamente vía el servicio
# "vault-init" (ver docker-compose.yml + vault-auto-init.sh). Usa este script
# a mano solo si el contenedor "vault" se reinicia por su cuenta (crash,
# `docker restart vault`, etc.) sin volver a correr "docker compose up".

echo "Esperando que Vault esté listo..."
sleep 8

echo "Habilitando motor Transit..."
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=vault_root_token vault vault secrets enable transit

echo "Creando llave clickloker-key..."
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=vault_root_token vault vault write -f transit/keys/clickloker-key

echo "Creando llave plataforma-key..."
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=vault_root_token vault vault write -f transit/keys/plataforma-key

echo "Vault listo."

## pa' ejecutar, usar: bash init-vault.sh