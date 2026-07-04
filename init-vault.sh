# infraestructura/init-vault.sh

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