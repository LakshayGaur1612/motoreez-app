/* Motoreez: shows the phone's own notifications and opens the right job
   card when one is tapped. It caches nothing, so app updates are never
   held back on anyone's phone. */
self.addEventListener('install', function(){ self.skipWaiting(); });
self.addEventListener('activate', function(e){ e.waitUntil(self.clients.claim()); });
self.addEventListener('notificationclick', function(e){
  e.notification.close();
  var job = (e.notification.data && e.notification.data.jobId) || '';
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(list){
    for (var i = 0; i < list.length; i++) {
      if (job) list[i].postMessage({ openJob: job });
      return list[i].focus();
    }
    return self.clients.openWindow('./' + (job ? '#job=' + job : ''));
  }));
});
