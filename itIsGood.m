% שלב 1: קבלת קובץ אודיו מהמשתמש
[fileName, filePath] = uigetfile({'*.mp3;*.wav', 'Audio Files (*.mp3, *.wav)'}, 'SELECT קובץ אודיו');
if isequal(fileName, 0)
    disp('לא נבחר קובץ.');
    return;
end

% קריאת הקובץ לאודיו
[audioData, sampleRate] = audioread(fullfile(filePath, fileName));

% אם האודיו הוא סטריאו, נבחר את הערוץ הראשון
if size(audioData, 2) > 1
    audioData = audioData(:, 1); % בחר את הערוץ הראשון (שמאלי)
end

% שלב 2: המרת קובץ אם אינו בפורמט WAV
if strcmpi(fileName(end-2:end), 'mp3')
    % המרת קובץ MP3 ל-WAV
    outputFileName = fullfile(filePath, 'audio.wav');
    audiowrite(outputFileName, audioData, sampleRate);
    disp('המרה ל-WAV בוצעה.');
else
    disp('הקובץ כבר בפורמט WAV.');
end

% שלב 3: קריאת הספקטרוגרמה של האודיו
window = 1024; % גודל החלון
overlap = 512; % חפיפות
nfft = 2048; % מספר חישובי ה-FFT
[S, F, T] = spectrogram(audioData, window, overlap, nfft, sampleRate); % הוספנו את F (תדרים) ו-T (זמן)



[~, maxIndex] = max(abs(S)); % מציאת המגניטודה המקסימלית
dominantFrequencies = F(maxIndex); % התדרים הדומיננטיים
synthesizedAudio = zeros(size(audioData)); % אתחול האות
dt = 1 / sampleRate; % מרווח דגימה

for k = 1:length(T)-1
    % זמן למקטע
    t = T(k):dt:T(k+1)-dt;
    
    % יצירת גל סינוסי בתדר הדומיננטי
    freq = dominantFrequencies(k); % התדר הדומיננטי במקטע
    synthesizedAudio(round(T(k)*sampleRate):round(T(k+1)*sampleRate)-1) = ...
        sin(2 * pi * freq * t);
end


note_frequencies = [261.63, 277.18, 293.66, 311.13, 329.63, 349.23, 369.99, 392.00, 415.30, 440.00, ...
                    466.16, 493.88, 523.25, 554.37, 587.33, 622.25, 659.25, 698.46, 739.99, ...
                    783.99, 830.61, 880.00, 932.33, 987.77, 1046.50, 1108.73, 1174.66, ...
                    1244.51, 1318.51];

notes_names = {'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B', 'C5', 'C#5', 'D5', ...
               'D#5', 'E5', 'F5', 'F#5', 'G5', 'G#5', 'A5', 'A#5', 'B5', 'C6', 'C#6', 'D6', ...
               'D#6', 'E6'};

% יצירת מילון מתאים בין תדרים לתווים
note_dict = containers.Map(note_frequencies, notes_names);

% הגדרת מגבלת מגניטודה
magnitude_threshold = 0.01; % קבע רף מינימלי לעוצמת האות (ניתן לכוונן לפי הצורך)

% זיהוי תווים בהתבסס על התדרים והעוצמות
detected_notes = cell(size(dominantFrequencies));
for i = 1:length(dominantFrequencies)
    % בדוק אם המגניטודה של התדר הדומיננטי עוברת את הסף
    if max(abs(S(:, i))) > magnitude_threshold
        % מצא את התדר הקרוב ביותר
        [~, index] = min(abs(note_frequencies - dominantFrequencies(i)));
        detected_notes{i} = note_dict(note_frequencies(index));
    %else
        % אם המגניטודה נמוכה מדי, ציין שאין תו
        %detected_notes{i} = '';
    end
end

% דחיסת התווים לפי שינוי ומעקב אחר משך הזמן שלהם
compressed_notes = {};  % רשימה חדשה לתווים ולמשך הזמן שלהם
durations = [];  % רשימת משכים
current_note = detected_notes{1};  % התו הראשון
count = 1;  % מונה משך התו הנוכחי



for i = 2:length(detected_notes)
    if strcmp(detected_notes{i}, current_note)
        % אם התו זהה לקודם, הגדל את המונה
        count = count + 1;
    else
        % אם התו שונה, שמור את התו והמשך
        compressed_notes{end+1} = current_note;
        durations(end+1) = count;  % משך התו
        current_note = detected_notes{i};  % עדכון התו הנוכחי
        count = 1;  % אתחול מונה למשך התו החדש
    end
end

% הוסף את התו האחרון לרשימה
compressed_notes{end+1} = current_note;
durations(end+1) = count;

% שלב 1: איחוד תווים חוזרים ומפוצלים
min_duration = 0.1;  % סף זמן מינימלי לתו (מינימום של 50ms)
current_note = detected_notes{1};
current_duration = 0;

i = 1;
while i < length(compressed_notes)
    duration_in_seconds = durations(i) * (window - overlap) / sampleRate;  % חישוב הזמן של התו
    if duration_in_seconds < min_duration  % אם הזמן קטן מהסף
        % אם יש תו זהה מיד לאחריו, נחשב את סך משך הזמן ונאחד
        if i < length(compressed_notes) && strcmp(compressed_notes{i}, compressed_notes{i+1})
            durations(i+1) = durations(i+1) + durations(i);  % איחוד משך הזמן
            compressed_notes(i) = [];  % מחיקת התו המשוכפל
            durations(i) = [];
            continue;  % חזרה להתחלה של הלולאה
        end
    end
    i = i + 1;
end



% שלב 4: השמעת הקובץ בזמן הריצה
%soundsc(audioData, sampleRate);

for i = 1:length(detected_notes)
    if ~isempty(detected_notes{i})
        disp(['תו: ', detected_notes{i}]);
    end
end


% שלב 5: הצגת התווים שהופיעו לפחות פעמיים ברצף
repeated_notes = {};  % רשימה לתווים שחוזרים לפחות פעמיים
count = 1;

for i = 2:length(detected_notes)
    if strcmp(detected_notes{i}, detected_notes{i-1})
        count = count + 1;  % אם התו הנוכחי זהה לזה הקודם
    else
        if count > 1
            repeated_notes{end+1} = detected_notes{i-1};  % הוסף את התו האחרון שהופיע לפחות פעמיים
        end
        count = 1;  % אתחול המונה
    end
end

% בדיקה אם התו האחרון חזר לפחות פעמיים
if count > 1
    repeated_notes{end+1} = detected_notes{end};
end

% הצגת התווים שהופיעו לפחות פעמיים ברצף
disp('התווים שהופיעו לפחות פעמיים ברצף:');
disp(strjoin(repeated_notes, ''));

% שלב 6: כתיבת התוצאות לקובץ טקסט
outputFile = fullfile(filePath, 'detected_notes.txt');
fileID = fopen(outputFile, 'w');
if fileID == -1
    disp('לא ניתן לפתוח את הקובץ לכתיבה.');
    return;
end

% כתיבת כותרת לקובץ
fprintf(fileID, 'תווים ומדידת זמן\n');

% עבור כל תו, כתוב את התו ואת משך הזמן
for i = 1:length(compressed_notes)
    note = compressed_notes{i};
    duration = durations(i) * (window - overlap) / sampleRate;  % זמן בשניות לכל תו
    
    % אם התו לא ריק ומשך הזמן מספיק (לפי הגדרת סף), נכתוב אותו
    if ~isempty(note) && duration > 0.04  % אם משך הזמן מעל 0.04 שניות
        fprintf(fileID, '%s: %.2f שניות\n', note, duration);
    end
end

% סגירת הקובץ
fclose(fileID);
disp(['התוצאות נכתבו לקובץ: ', outputFile]);

% שלב 7: קריאת התווים מהקובץ ויצירת גל סינוסי לנגינה
% קריאה מהקובץ
outputFile = fullfile(filePath, 'detected_notes.txt');
fid = fopen(outputFile, 'r');
if fid == -1
    disp('לא ניתן לפתוח את הקובץ לקריאה.');
    return;
end

% דילוג על כותרת הקובץ
fgetl(fid);
soundOutput = [];  % מיכל לאודיו המתקבל
for i = 1:length(compressed_notes)
    note = compressed_notes{i};
    duration = durations(i) * (window - overlap) / sampleRate;  % זמן בשניות לכל תו
    
        % אם התו נמצא במערך התווים החוזרים והוא מעל 0.04 שניות, ננגן אותו
    if any(ismember(string(note), string(repeated_notes))) && duration > 0.04
            % מציאת התדר המתאים לכל תו
            [~, index] = ismember(note, notes_names);
            frequency = note_frequencies(index);
            
            % יצירת גל סינוסי למשך הזמן של התו
            t = 0:1/sampleRate:duration;  % זמן התו
            noteWave = sin(2 * pi * frequency * t);  % גל סינוסי
    
            % הוספת גל התו לקובץ הסאונד הכללי
            soundOutput = [soundOutput, noteWave];
        end
end

% שמירת הצלילים כקובץ MP3
outputSoundFile = fullfile(filePath, 'output_audio.mp3');
audiowrite(outputSoundFile, soundOutput, sampleRate);
disp(['הקובץ נשמר כ-', outputSoundFile]);

fclose(fid);


% שלב 8: סיווג התווים לפי המשך שלהם

% טבלת השוואה למשכי התווים
note_durations = [4.00, 3.00, 2.00, 1.50, 1.00, 0.50, 0.25];
note_types = {'תו שלם (𝅝)', 'תו חצי עם נקודה (𝅗𝅥.)', 'תו חצי (𝅗𝅥)', 'תו רבע עם נקודה (♩.)', 'תו רבע (♩)', 'תו שמינית (♪)', 'תו שש-עשרית (♫)'};

duration_classification = {}; % משתנה לאחסון סוג התו שזוהה

tolerance = 0.03; % סף סטייה בזיהוי (10%)

for i = 1:length(compressed_notes)
    note = compressed_notes{i};
    duration = durations(i) * (window - overlap) / sampleRate;  % חישוב זמן בשניות
    
    % מציאת ההתאמה הקרובה ביותר למשכי התווים
    [~, index] = min(abs(note_durations - duration));
    classified_note = note_types{index};
    
    % שמירת התוצאה
    duration_classification{i} = sprintf('%s: %s (%.2f שניות)', note, classified_note, duration);
end

% כתיבת התוצאות לקובץ נוסף
outputFileClassified = fullfile(filePath, 'classified_notes.txt');
fileID = fopen(outputFileClassified, 'w');
if fileID == -1
    disp('לא ניתן לפתוח את הקובץ לכתיבה.');
    return;
end

fprintf(fileID, 'תווים וסוגי משכים\n');
for i = 1:length(duration_classification)
   if durations(i) * (window - overlap) / sampleRate > 0.05
    fprintf(fileID, '%s\n', duration_classification{i});
   end
end
fclose(fileID);
disp(['סיווג התווים נכתב לקובץ: ', outputFileClassified]);

% שלב 9: הצגת התווים על גבי חמשה

% שלב 9: הצגת התווים על גבי חמשה מתוך קובץ classified_notes

% קריאת התווים מקובץ classified_notes.txt
classified_file = fullfile(filePath, 'classified_notes.txt');
fid = fopen(classified_file, 'r');
if fid == -1
    disp('לא ניתן לפתוח את קובץ classified_notes.txt');
    return;
end

% דילוג על כותרת הקובץ
fgetl(fid);

% קריאת התווים מהקובץ
classified_notes = {};
while ~feof(fid)
    line = fgetl(fid);
    parts = strsplit(line, ':');
    if length(parts) >= 2
        note = strtrim(parts{1}); % התו
        classified_notes{end+1} = note; % הוסף לתו שנמצא
    end
end

fclose(fid);

% הצגת התווים על גבי חמשה
figure;
hold on;
axis([0, length(classified_notes)*2, 0, 10]); % התאמת הגבולות לגובה
set(gca, 'YTick', 1:10, 'YTickLabel', {'C', 'D', 'E', 'F', 'G', 'A', 'B', 'C5', 'D5', 'E5'});
title('תווים על גבי חמשה');
xlabel('זמן');
ylabel('גובה תו');

% ציור החמשה
for line = [2, 4, 6, 8, 10]  % ציור 5 קווים (התווים יפלו באמצע)
    plot([0, length(classified_notes)*2], [line, line], 'k', 'LineWidth', 2);
end

x_pos = 1; % מיקום אופקי ראשוני לתו

% יצירת מיפוי של התווים ללא קווים נפרדים לדיאזים
note_order = {'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B', 'C5', 'C#5', 'D5', 'D#5', 'E5'};
note_base = {'C', 'D', 'E', 'F', 'G', 'A', 'B', 'C5', 'D5', 'E5'};
note_map = containers.Map(note_base, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]); % מיפוי רק לתווים בסיסיים

for i = 1:length(classified_notes)
    note = classified_notes{i};
    
    if isempty(note)
        % אם אין תו (הפסקה), נתקדם במרווח אופקי
        x_pos = x_pos + 2;
        continue;
    end
    
    % מציאת המיקום האנכי של התו על פי התו הבסיסי שלו
    base_note = erase(note, '#'); % מסירים את ה# אם קיים
    if isKey(note_map, base_note)
        y_pos = note_map(base_note);
    else
        y_pos = NaN;
    end
    
    % בדיקה שהתו תקין
    if ~isnan(y_pos)
        % ציור עיגול כתו
        plot(x_pos, y_pos, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 12);
        
        % אם מדובר בתו עם דיאז, נוסיף סימן '#' לידו
        if contains(note, '#')
            text(x_pos + 0.3, y_pos, '#', 'FontSize', 14, 'FontWeight', 'bold');
        end
    end
    
    % התקדמות אופקית - קבועה לכל תו
    x_pos = x_pos + 2; % מרווח אחיד בין תווים
end

hold off;



