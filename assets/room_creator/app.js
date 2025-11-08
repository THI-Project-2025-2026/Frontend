(function () {
  const handlerName = 'roomCreatorChannel';
  const bridgeContext = 'roomCreatorBridge';
  const statusValue = document.getElementById('status-value');
  const description = document.getElementById('description');
  const heading = document.getElementById('heading');
  const sendButton = document.getElementById('send-button');

  function updateStatus(text) {
    statusValue.textContent = text;
  }

  function postToFlutter(type, value) {
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview
        .callHandler(handlerName, type === 'ready' ? 'ready' : String(value ?? ''))
        .catch((error) => console.warn('Message send failed', error));
      return;
    }

    if (window.parent && window.parent !== window) {
      const payload = {
        context: bridgeContext,
        type,
        value: typeof value === 'undefined' ? null : value,
      };
      window.parent.postMessage(JSON.stringify(payload), '*');
    }
  }

  const roomCreator = {
    setTheme(mode) {
      const theme = mode === 'dark' ? 'dark' : 'light';
      document.body.classList.remove('light', 'dark');
      document.body.classList.add(theme);
      description.textContent =
        theme === 'dark'
          ? 'Dark theme enabled via Flutter context.'
          : 'Light theme enabled via Flutter context.';
    },
    receiveMessage(message) {
      updateStatus(String(message || ''));
    },
    sendMessageToFlutter(message) {
      const payload = String(message || '');
      updateStatus(`JS sent: ${payload}`);
      postToFlutter('message', payload);
    },
    notifyReady() {
      postToFlutter('ready');
    }
  };

  window.roomCreator = roomCreator;

  window.addEventListener('message', (event) => {
    let payload = event.data;
    if (!payload) {
      return;
    }

    if (typeof payload === 'string') {
      try {
        payload = JSON.parse(payload);
      } catch (error) {
        return;
      }
    }

    if (!payload || payload.context !== bridgeContext) {
      return;
    }

    switch (payload.type) {
      case 'setTheme':
        roomCreator.setTheme(payload.value);
        break;
      case 'message':
        roomCreator.receiveMessage(payload.value);
        break;
    }
  });

  sendButton?.addEventListener('click', function () {
    roomCreator.sendMessageToFlutter('Ping from room creator');
  });

  heading.textContent = 'Room creation demo';
  updateStatus('Bridge idle');
  roomCreator.notifyReady();
})();
