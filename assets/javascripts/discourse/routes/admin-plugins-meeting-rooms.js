import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsMeetingRoomsRoute extends DiscourseRoute {
  model() {
    return ajax("/plugnmeet/rooms").catch(popupAjaxError);
  }
}
