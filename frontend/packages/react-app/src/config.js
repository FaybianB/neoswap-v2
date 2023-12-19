import { Sepolia } from "@usedapp/core";
import { getDefaultProvider } from "ethers";

export const ROUTER_ADDRESS = "0xcC891C6D952152Aabd5e627AdEfD6b60a8Aa874d";

export const DAPP_CONFIG = {
  readOnlyChainId: Sepolia.chainId,
  readOnlyUrls: {
    [Sepolia.chainId]: process.env.REACT_APP_ALCHEMY_API_KEY,
  },
};
