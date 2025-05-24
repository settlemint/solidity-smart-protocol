import type { Address } from "viem";
import { SMARTContracts } from "../../constants/contracts";
import SMARTRoles from "../../constants/roles";
import { getDefaultWalletClient } from "../../utils/default-signer";
import {
  getContractInstance,
  getContractInstanceWithDefaultWalletClient,
} from "../../utils/get-contract";

// The issuer doesn't need to have a claim manager role, it can be anyone that adds the claim.
// The issuer will create the claim and the claim manager will add it to the token identity.
export const grantClaimManagerRole = async (
  accessManagerAddress: Address,
  claimIssuerAddress: Address
) => {
  const accessManagerContract =
    await getContractInstanceWithDefaultWalletClient({
      address: accessManagerAddress,
      abi: SMARTContracts.accessManager,
    });

  accessManagerContract.write.grantRole([
    SMARTRoles.claimManagerRole,
    claimIssuerAddress,
  ]);
};
