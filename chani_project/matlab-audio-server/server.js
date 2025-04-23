const fs = require('fs');
const path = require('path');
const express = require('express');
const multer = require('multer');
const cors = require('cors'); // הוספת cors
const { exec } = require('child_process');

const app = express();

// הוספת CORS לכל הבקשות
app.use(cors());

// הגדרת multer לאחסון הקבצים בתיקיית uploads
const upload = multer({ dest: 'uploads/' });

app.use(express.json()); // לאפשר קריאת JSON ב-body של הבקשות

app.post('/upload', upload.single('audio'), (req, res) => {

  console.log('Received file:', req.file);  // מוודא שהקובץ התקבל
  const file = req.file;
  if (!file) {
    return res.status(400).send('No file uploaded');
  }
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }

  console.log(req.body); // הדפסת הנתונים המתקבלים

  const audioFilePath = req.file.path;
  console.log('📁 Uploaded file:', req.file);

  const matlabCommand = `matlab -batch "analyze_audio('${audioFilePath}')"`; // ביצוע פקודת MATLAB

  exec(matlabCommand, (err, stdout, stderr) => {
    if (err) {
      console.error('❌ MATLAB error:', stderr);
      return res.status(500).json({ error: 'MATLAB processing failed' });
    }

    const resultPath = path.join(__dirname, 'uploads', 'classified_notes.json');

    if (!fs.existsSync(resultPath)) {
      return res.status(404).json({ error: 'Result file not found' });
    }

    fs.readFile(resultPath, 'utf8', (err, data) => {
      if (err) {
        return res.status(500).json({ error: 'Failed to read result file' });
      }

      return res.json(JSON.parse(data));
    });
  });
});

app.listen(3001, () => {
  console.log('Server running on port 3001');
});
