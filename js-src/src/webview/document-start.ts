// import 'whatwg-fetch';
// import './util/override-logging';
import './navigator/service-worker';
import './console';
import './messages/message-channel';
import './util/generic-events';
import './notification/notification';
import './util/set-document-html';

window.onerror = function(err) {
    console.error(err);
}

// document.body.innerHTML="THIS LOADED"