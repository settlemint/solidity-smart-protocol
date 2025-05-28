import {
  TopicSchemeRegistered,
  TopicSchemeRemoved,
  TopicSchemeUpdated,
  TopicSchemesBatchRegistered,
} from "../../../generated/templates/TopicSchemeRegistry/TopicSchemeRegistry";
import { fetchEvent } from "../event/fetch/event";
import { fetchTopicScheme } from "./fetch/topic-scheme";

export function handleTopicSchemeRegistered(
  event: TopicSchemeRegistered
): void {
  fetchEvent(event, "TopicSchemeRegistered");
  const topicScheme = fetchTopicScheme(event.params.topicId);
  topicScheme.signature = event.params.signature;
  topicScheme.save();
}

export function handleTopicSchemeRemoved(event: TopicSchemeRemoved): void {
  fetchEvent(event, "TopicSchemeRemoved");
  const topicScheme = fetchTopicScheme(event.params.topicId);
  topicScheme.enabled = false;
  topicScheme.save();
}

export function handleTopicSchemeUpdated(event: TopicSchemeUpdated): void {
  fetchEvent(event, "TopicSchemeUpdated");
  const topicScheme = fetchTopicScheme(event.params.topicId);
  topicScheme.signature = event.params.newSignature;
  topicScheme.save();
}

export function handleTopicSchemesBatchRegistered(
  event: TopicSchemesBatchRegistered
): void {
  fetchEvent(event, "TopicSchemesBatchRegistered");
}
