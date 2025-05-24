import {
  type Abi,
  type Address,
  type GetContractReturnType,
  type PublicClient,
  type WalletClient,
  getContract as getViemContract,
} from "viem";
import { getDefaultWalletClient } from "./default-signer";
import { getPublicClient } from "./public-client";

/**
 * Creates a Viem contract instance.
 *
 * @template TAbi - The ABI of the contract.
 * @param {Object} params - The parameters for creating the contract instance.
 * @param {Address} params.address - The address of the contract.
 * @param {TAbi} params.abi - The ABI of the contract.
 * @param {PublicClient} params.publicClient - The Viem PublicClient.
 * @param {WalletClient} params.walletClient - The Viem WalletClient.
 * @returns {GetContractReturnType<TAbi, { public: PublicClient; wallet: WalletClient }>} The Viem contract instance.
 */
export function getContractInstance<TAbi extends Abi>({
  address,
  abi,
  walletClient,
}: {
  address: Address;
  abi: TAbi;
  walletClient: WalletClient;
}): GetContractReturnType<
  TAbi,
  { public: PublicClient; wallet: WalletClient }
> {
  return getViemContract({
    address,
    abi,
    client: { public: getPublicClient(), wallet: walletClient },
  });
}

export async function getContractInstanceWithDefaultWalletClient<
  TAbi extends Abi
>({
  address,
  abi,
}: {
  address: Address;
  abi: TAbi;
}): Promise<
  GetContractReturnType<TAbi, { public: PublicClient; wallet: WalletClient }>
> {
  const defaultWalletClient = await getDefaultWalletClient();
  return getContractInstance({
    address,
    abi,
    walletClient: defaultWalletClient,
  });
}
