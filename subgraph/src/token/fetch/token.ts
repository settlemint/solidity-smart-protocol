import { Address } from "@graphprotocol/graph-ts";
import { Token } from "../../../../generated/schema";
import {
  Burnable as BurnableTemplate,
  Token as TokenTemplate,
} from "../../../../generated/templates";
import { Token as TokenContract } from "../../../../generated/templates/Token/Token";
import { fetchAccount } from "../../account/fetch/account";
import { setBigNumber } from "../../utils/bignumber";
import { InterfaceIds } from "../../erc165/utils/interfaceids";
import { fetchPausable } from "../../pausable/fetch/pausable";
import { fetchCustodian } from "../../custodian/fetch/custodian";

export function fetchToken(address: Address): Token {
  let token = Token.load(address);

  if (!token) {
    token = new Token(address);
    token.account = fetchAccount(address).id;
    token.type = "unknown";

    const tokenContract = TokenContract.bind(address);
    token.name = tokenContract.name();
    token.symbol = tokenContract.symbol();
    token.decimals = tokenContract.decimals();
    setBigNumber(
      token,
      "totalSupply",
      tokenContract.totalSupply(),
      token.decimals,
    );

    token.save();
    TokenTemplate.create(address);

    if (tokenContract.supportsInterface(InterfaceIds.ISMARTPausable)) {
      token.pausable = fetchPausable(address).id;
      token.save();
    }
    if (tokenContract.supportsInterface(InterfaceIds.ISMARTBurnable)) {
      BurnableTemplate.create(address);
    }
    if (tokenContract.supportsInterface(InterfaceIds.ISMARTCustodian)) {
      fetchCustodian(address);
    }
  }

  return token;
}
