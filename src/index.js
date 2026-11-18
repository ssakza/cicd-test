const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
    res.json({
        message: 'Hello from Jenkins CI/CD Demo!',
        version: process.env.APP_VERSION || '1.0.0',
        timestamp: new Date().toISOString()
    });
});

app.get('/health', (req, res) => {
    res.json({ status: 'healthy' });
});

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
// GitOps test - 2026-11-18 15:51:15
