import { Sepolia } from "@usedapp/core";
import { getDefaultProvider } from "ethers";

export const ROUTER_ADDRESS = "0x3ff845bd9338381587fca647a93c6b1bfa87c501";

export const DAPP_CONFIG = {
  readOnlyChainId: Sepolia.chainId,
  readOnlyUrls: {
    [Sepolia.chainId]: process.env.REACT_APP_ALCHEMY_API_KEY,
  },
};
