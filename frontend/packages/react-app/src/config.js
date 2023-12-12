import { Sepolia } from "@usedapp/core";
import { getDefaultProvider } from 'ethers'

export const ROUTER_ADDRESS = "[YOUR ADDRESS HERE]";

export const DAPP_CONFIG = {
  readOnlyChainId: Sepolia.chainId,
  readOnlyUrls: {
    [Sepolia.chainId]: getDefaultProvider('sepolia'),
  },
};