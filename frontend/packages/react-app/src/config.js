import { Sepolia } from "@usedapp/core";
import { getDefaultProvider } from "ethers";

export const ROUTER_ADDRESS = "0x1e156e18b616de4dad6ffc4448956228be6d1d16";

export const DAPP_CONFIG = {
  readOnlyChainId: Sepolia.chainId,
  readOnlyUrls: {
    [Sepolia.chainId]: process.env.REACT_APP_ALCHEMY_API_KEY,
  },
};
