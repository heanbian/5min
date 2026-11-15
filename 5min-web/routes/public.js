'use strict';

function sendOk(res, data) {
  res.json({ success: true, data });
}

function registerPublicRoutes(app) {
  app.get('/api/status', (req, res) => {
    sendOk(res, {
      name: '5min',
      product: '如厕计时器(5min)',
      origin: 'https://5min.chat'
    });
  });
}

module.exports = registerPublicRoutes;
