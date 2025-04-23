function analyze_audio(filePath)

    fprintf("🔍 Analyzing file: %s\n", filePath);

    disp(['Reading audio file: ', filePath]);
    disp(['קובץ התקבל: ', filePath]);
    % קריאת הקובץ לאודיו
    [audioData, sampleRate] = audioread(filePath);

    % אם האודיו הוא סטריאו, נבחר את הערוץ הראשון
    if size(audioData, 2) > 1
        audioData = audioData(:, 1); % בחר את הערוץ הראשון (שמאלי)
    end

    % שלב 2: המרת קובץ אם אינו בפורמט WAV
    if strcmpi(filePath(end-2:end), 'mp3')
        disp('מתחיל המרה ל-WAV...');
        % המרת קובץ MP3 ל-WAV
        [~, fileName, ~] = fileparts(filePath);   % קבלת שם הקובץ בלי סיומת
        outputfilePath = fullfile(fileparts(filePath), [fileName, '_converted.wav']);   % שמירה באותו תיק עם שם חדש
        audiowrite(outputfilePath, audioData, sampleRate);
        disp(['המרה ל-WAV בוצעה, קובץ שמור ב: ', outputfilePath]);
        filePath = outputfilePath; % עדכון נתיב הקובץ ל-WAV המומר
        disp(['ניתוח יתבצע על קובץ: ', filePath]);
    else
        disp('הקובץ כבר בפורמט WAV.');
    end

    % שלב 3: קריאת הספקטרוגרמה של האודיו
    window = 1024; % גודל החלון
    overlap = 512; % חפיפות
    nfft = 2048; % מספר חישובי ה-FFT
    [S, F, T] = spectrogram(audioData, window, overlap, nfft, sampleRate); % הוספנו את F (תדרים) ו-T (זמן)

    % ... (הערות על הצגת ספקטרוגרמה ו-FFT הוסרו כדי לשמור על בהירות) ...

    % חישוב התדרים הדומיננטיים
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

    % ... (הערות על הצגת הגל הסינתטי הוסרו) ...

    % יצירת מילון מתאים בין תדרים לתווים
    note_frequencies = [261.63, 277.18, 293.66, 311.13, 329.63, 349.23, 369.99, 392.00, 415.30, 440.00, ...
                        466.16, 493.88, 523.25, 554.37, 587.33, 622.25, 659.25, 698.46, 739.99, ...
                        783.99, 830.61, 880.00, 932.33, 987.77, 1046.50, 1108.73, 1174.66, ...
                        1244.51, 1318.51];

    notes_names = {'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B', 'C5', 'C#5', 'D5', ...
                   'D#5', 'E5', 'F5', 'F#5', 'G5', 'G#5', 'A5', 'A#5', 'B5', 'C6', 'C#6', 'D6', ...
                   'D#6', 'E6'};

    note_dict = containers.Map(note_frequencies, notes_names);  % יצירת מילון של תדרים לתווים

    magnitude_threshold = 0.01;   % רף מינימלי לעוצמת האות

    % זיהוי תווים בהתבסס על התדרים והעוצמות
    detected_notes = cell(size(dominantFrequencies));
    for i = 1:length(dominantFrequencies)
        if max(abs(S(:, i))) > magnitude_threshold     % אם המגניטודה גבוהה מספיק
            [~, index] = min(abs(note_frequencies - dominantFrequencies(i)));      % מצא את התדר הקרוב ביותר
            detected_notes{i} = note_dict(note_frequencies(index));      % שמור את התו
        end
    end

    % ... (הערות על הצגת זיהוי תווים הוסרו) ...

    % דחיסת התווים לפי שינוי ומעקב אחר משך הזמן
    compressed_notes = {};     % רשימה חדשה לתווים ולמשך הזמן שלהם
    durations_windows = [];      % רשימת משכים בחלונות
    if ~isempty(detected_notes)
        current_note = detected_notes{1};      % התו הראשון
        count = 1;      % מונה משך התו הנוכחי

        for i = 2:length(detected_notes)
            if strcmp(detected_notes{i}, current_note)      % אם התו זהה לקודם, הגדל את המונה
                count = count + 1;
            else       % אם התו שונה, שמור את התו והמשך
                compressed_notes{end+1} = current_note;
                durations_windows(end+1) = count;      % משך התו בחלונות
                current_note = detected_notes{i};      % עדכון התו הנוכחי
                count = 1;      % אתחול מונה למשך התו החדש
            end
        end

        % הוסף את התו האחרון לרשימה
        compressed_notes{end+1} = current_note;
        durations_windows(end+1) = count;
    end

    % הצגת תהליך דחיסת התווים ומעקב אחר משך הזמן
    disp('תווים דחוסים:');
    disp(compressed_notes);
    disp('משכי זמן (בחלונות):');
    disp(durations_windows);

    % שלב 1: איחוד תווים חוזרים ומפוצלים
    min_duration_seconds = 0.1;       % סף זמן מינימלי לתו
    i = 1;
    while i < length(compressed_notes)
        duration_seconds = durations_windows(i) * (window - overlap) / sampleRate;        % חישוב הזמן של התו בשניות
        if duration_seconds < min_duration_seconds        % אם הזמן קטן מהסף
            % אם יש תו זהה מיד לאחריו, נחשב את סך משך הזמן ונאחד
            if i < length(compressed_notes) && strcmp(compressed_notes{i}, compressed_notes{i+1})
                durations_windows(i+1) = durations_windows(i+1) + durations_windows(i);        % איחוד משך הזמן בחלונות
                compressed_notes(i) = [];        % מחיקת התו המשוכפל
                durations_windows(i) = [];
                continue;       % חזרה להתחלה של הלולאה
            end
        end
        i = i + 1;
    end

    % הצגת התוצאה הסופית לאחר האיחוד
    disp('תוצאה סופית לאחר איחוד תווים:');
    disp(compressed_notes);
    disp('משכי זמן לאחר איחוד (בחלונות):');
    disp(durations_windows);

    % שלב 8: סיווג התווים לפי המשך שלהם (הסיווג לסוג יוסר)
    final_classified_notes = {};
    final_durations_seconds = [];

    for i = 1:length(compressed_notes)
        note = compressed_notes{i};
        duration_seconds = durations_windows(i) * (window - overlap) / sampleRate;      % חישוב זמן בשניות

        if duration_seconds > 0.05
            final_classified_notes{end+1} = note;
            final_durations_seconds(end+1) = duration_seconds;
            disp(['תו: ', note, ' (', num2str(duration_seconds), ' שניות)']);
        end
    end

    % כתיבת התוצאות לקובץ classified_notes.txt (ללא סוג התו)
    [fileDir, ~, ~] = fileparts(filePath);
    outputFileClassified = fullfile(fileDir, 'classified_notes.txt');
    disp(['מנסה לכתוב ל-classified_notes.txt בנתיב: ', outputFileClassified]);
    fileID = fopen(outputFileClassified, 'w');
    if fileID == -1
        disp('שגיאה: לא ניתן לפתוח את הקובץ לכתיבה.');
        return;
    end

    % כתיבת כותרת לקובץ
    fprintf(fileID, 'תווים ומשכי זמן (בשניות)\n');

    % עבור כל תו, אם משך הזמן מעל 0.05 שניות, נכתוב את התו והמשך לקובץ
    for i = 1:length(final_classified_notes)
        duration_seconds = final_durations_seconds(i);
        fprintf(fileID, 'תו: %s, משך: %.2f שניות\n', final_classified_notes{i}, duration_seconds);
    end

    % סגירת הקובץ
    fclose(fileID);
    disp(['סיווג התווים נכתב לקובץ: ', outputFileClassified]);

    % יצירת מבנה JSON עם התוצאות (ללא סוג התו)
    output.notes = struct('note', final_classified_notes', 'duration', num2cell(final_durations_seconds'));

    % יצירת נתיב לקובץ JSON
    [~, fileName, ~] = fileparts(filePath);
    jsonOutputPath = fullfile(pwd, 'uploads', 'classified_notes.json');
    disp(['מנסה לכתוב ל-_classified_notes.json בנתיב: ', jsonOutputPath]);
    if ~exist('uploads', 'dir')
        mkdir('uploads');
        disp('תיקיית uploads נוצרה.');
    end
    % כתיבת התוצאה לקובץ JSON
    fid = fopen(jsonOutputPath, 'w');
    if fid == -1
        disp('שגיאה: לא ניתן לפתוח את הקובץ _classified_notes.json לכתיבה.');
        return;
    end

    % כתיבה לקובץ JSON
    fwrite(fid, jsonencode(output));
    fclose(fid);
    disp(['הנתונים נכתבו לקובץ: ', jsonOutputPath]);
end

function [note, octave] = frequency_to_note(freq)
    % תדרי רפרנס
    A4 = 440;
    note_names = {'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'};
    
    % חישוב מרחק חצי-טון מהתו A4
    n = round(12 * log2(freq / A4));
    
    % חישוב תו ואוקטבה
    note_index = mod(n + 9, 12) + 1;  % A4 = index 10 → C = 1
    note = note_names{note_index};
    octave = 4 + floor((n + 9) / 12);
end