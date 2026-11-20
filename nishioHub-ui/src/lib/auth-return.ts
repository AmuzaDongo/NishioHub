import {resourcePageReturn} from './resource-page-api';
import { libraryReturn } from './public-learning-api';
import { publicEventReturn } from './public-events-api';
// Fixed internal destinations only; never accept arbitrary URLs from the query string.
export function safeAuthReturn(value: string | null) {
 return value === '/mentor/application' || value === '/host-an-event' ? value : resourcePageReturn(value) || libraryReturn(value) || publicEventReturn(value);
}
