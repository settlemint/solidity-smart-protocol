import { Address, BigInt, Bytes } from "@graphprotocol/graph-ts";
import { TopicScheme } from "../../../../generated/schema";

export function fetchTopicScheme(topicId: BigInt): TopicScheme {
  const id = Bytes.fromUTF8(topicId.toHexString());
  let topicScheme = TopicScheme.load(id);

  if (!topicScheme) {
    topicScheme = new TopicScheme(id);
    topicScheme.topicId = topicId;
    topicScheme.registry = Address.zero();
    topicScheme.signature = "";
    topicScheme.enabled = true;
    topicScheme.save();
  }

  return topicScheme;
}
