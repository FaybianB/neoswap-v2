import { Sepolia } from "@usedapp/core";
import { getDefaultProvider } from "ethers";

export const ROUTER_ADDRESS = "0xb744A692B346FFDdB6Ee3eD0E668164962B0e920";

export const DAPP_CONFIG = {
    readOnlyChainId: Sepolia.chainId,
    readOnlyUrls: {
        [Sepolia.chainId]: process.env.REACT_APP_ALCHEMY_API_KEY,
    },
};
