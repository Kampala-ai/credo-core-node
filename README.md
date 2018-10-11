# Credo Core Node

Credo Core Node is a full node for participating in the Credo blockchain network.

## Services

This node provides the following services:

1. Peer-to-peer network communication and connection management
2. Pending transaction construction, storage, and broadcasting
3. Block synchronization
4. Validator participation

## Tech Stack

This node is implemented in the Elixir/Phoenix and uses Mnesia for storage of p2p and blockchain meta data.

## Starting the node

To start the node:

  * Install dependencies with `mix deps.get`
  * Start Phoenix endpoint with `mix phx.server`
