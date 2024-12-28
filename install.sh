#!/bin/bash

# Generar artefactos de configuración
cryptogen generate --config=./config/crypto-config.yaml --output=./crypto-config || { echo "Error: Generating crypto material failed"; exit 1; }

configtxgen -profile OrdererGenesis -channelID system-channel -outputBlock ./channel-artifacts/genesis.block || { echo "Error: Generating genesis block failed"; exit 1; }

configtxgen -profile ChannelConfig -channelID marketplace -outputCreateChannelTx ./channel-artifacts/marketplace.tx || { echo "Error: Generating channel transaction failed"; exit 1; }

configtxgen -profile ChannelConfig -channelID marketplace -outputAnchorPeersUpdate ./channel-artifacts/BuyerMSPanchors.tx -asOrg BuyerMSP || { echo "Error: Generating Buyer anchor peers failed"; exit 1; }

configtxgen -profile ChannelConfig -channelID marketplace -outputAnchorPeersUpdate ./channel-artifacts/SellerMSPanchors.tx -asOrg SellerMSP || { echo "Error: Generating Seller anchor peers failed"; exit 1; }

configtxgen -profile ChannelConfig -channelID marketplace -outputAnchorPeersUpdate ./channel-artifacts/ClientMSPanchors.tx -asOrg ClientMSP || { echo "Error: Generating Client anchor peers failed"; exit 1; }

# Levantar la red
docker-compose -f ./docker/docker-compose.yaml up -d || { echo "Error: Starting Docker containers failed"; exit 1; }

# Verificar si los contenedores están corriendo
docker ps || { echo "Error: Docker containers not running"; exit 1; }

# Crear el canal
docker exec -it cli peer channel create -o orderer1.etsi.com:7050 -c marketplace -f ./channel-artifacts/marketplace.tx --tls --cafile /etc/hyperledger/fabric/tls/ca.crt || { echo "Error: Creating channel failed"; exit 1; }

# Unir los peers al canal
docker exec -it peer0.buyer.etsi.com peer channel join -b marketplace.block || { echo "Error: Peer0.buyer failed to join channel"; exit 1; }
docker exec -it peer0.seller.etsi.com peer channel join -b marketplace.block || { echo "Error: Peer0.seller failed to join channel"; exit 1; }
docker exec -it peer0.client.etsi.com peer channel join -b marketplace.block || { echo "Error: Peer0.client failed to join channel"; exit 1; }

# Actualizar Anchor Peers
docker exec -it peer0.buyer.etsi.com peer channel update -o orderer1.etsi.com:7050 -c marketplace -f ./channel-artifacts/BuyerMSPanchors.tx --tls --cafile /etc/hyperledger/fabric/tls/ca.crt || { echo "Error: Updating Buyer anchor peers failed"; exit 1; }

docker exec -it peer0.seller.etsi.com peer channel update -o orderer1.etsi.com:7050 -c marketplace -f ./channel-artifacts/SellerMSPanchors.tx --tls --cafile /etc/hyperledger/fabric/tls/ca.crt || { echo "Error: Updating Seller anchor peers failed"; exit 1; }

docker exec -it peer0.client.etsi.com peer channel update -o orderer1.etsi.com:7050 -c marketplace -f ./channel-artifacts/ClientMSPanchors.tx --tls --cafile /etc/hyperledger/fabric/tls/ca.crt || { echo "Error: Updating Client anchor peers failed"; exit 1; }
