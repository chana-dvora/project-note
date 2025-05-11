function analyze_audio(filePath)

    %-------------------------------------
    %שלב 1: קריאת קובץ האודיו
    %-------------------------------------
    fprintf("🔍 Analyzing file: %s\n", filePath);
    [audioData, sampleRate] = audioread(filePath);                                       % קריאת הקובץ לאודיו                                                                                  
    if size(audioData, 2) > 1                                                            % אם האודיו הוא סטריאו, נבחר את הערוץ הראשון
        audioData = audioData(:, 1); 
    end

    %--------------------------------------------
    % שלב 2: המרת קובץ אם אינו בפורמט WAV
    %--------------------------------------------
    if strcmpi(filePath(end-2:end), 'mp3')
        [~, fileName, ~] = fileparts(filePath);                                         % קבלת שם הקובץ בלי סיומת
        outputfilePath = fullfile(fileparts(filePath), [fileName, '_converted.wav']);   % שמירה באותו תיקיה עם שם חדש
        audiowrite(outputfilePath, audioData, sampleRate);
        filePath = outputfilePath;                                                      % עדכון נתיב הקובץ ל-WAV המומר
    end

    %-------------------------------------------
    % שלב 3: קריאת הספקטרוגרמה של האודיו
    %-------------------------------------------
    window = 1024;                                                                       % גודל החלון
    overlap = 512;                                                                       % חפיפות
    nfft = 2048;                                                                         % מספר חישובי ה-FFT
    [S, F, T] = spectrogram(audioData, window, overlap, nfft, sampleRate);               % T=זמן, F=תדרים

    %---------------------------------------
    %שלב 4: חישוב התדרים הדומיננטיים
    %---------------------------------------
    [~, maxIndex] = max(abs(S));                                                         % מציאת המגניטודה המקסימלית
    dominantFrequencies = F(maxIndex);                                                   % התדרים הדומיננטיים
    synthesizedAudio = zeros(size(audioData));                                           % אתחול האות
    dt = 1 / sampleRate;                                                                 % מרווח דגימה

    for k = 1:length(T)-1                                                                % יצירת גל סינוסי בתדר הדומיננטי
        t = T(k):dt:T(k+1)-dt;                                                           % זמן למקטע
        freq = dominantFrequencies(k);                                                 
        synthesizedAudio(round(T(k)*sampleRate):round(T(k+1)*sampleRate)-1) = ...
            sin(2 * pi * freq * t);
    end

                                                                                         % יצירת מילון מתאים בין תדרים לתווים
    note_frequencies = [261.63, 277.18, 293.66, 311.13, 329.63, 349.23, 369.99, 392.00, 415.30, 440.00, ...
                        466.16, 493.88, 523.25, 554.37, 587.33, 622.25, 659.25, 698.46, 739.99, ...
                        783.99, 830.61, 880.00, 932.33, 987.77, 1046.50, 1108.73, 1174.66, ...
                        1244.51, 1318.51];

    notes_names = {'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B', 'C5', 'C#5', 'D5', ...
                   'D#5', 'E5', 'F5', 'F#5', 'G5', 'G#5', 'A5', 'A#5', 'B5', 'C6', 'C#6', 'D6', ...
                   'D#6', 'E6'};

    note_dict = containers.Map(note_frequencies, notes_names);                            % יצירת מילון של תדרים לתווים
    magnitude_threshold = 0.01;                                                           % רף מינימלי לעוצמת האות

    %------------------------------------------------------
    % שלב 5:זיהוי תווים בהתבסס על התדרים והעוצמות
    %------------------------------------------------------
    detected_notes = cell(size(dominantFrequencies));
    for i = 1:length(dominantFrequencies)
        if max(abs(S(:, i))) > magnitude_threshold                                        % אם המגניטודה גבוהה מספיק
            [~, index] = min(abs(note_frequencies - dominantFrequencies(i)));             % מצא את התדר הקרוב ביותר
            detected_notes{i} = note_dict(note_frequencies(index));                       % שמור את התו
        end
    end

    %--------------------------------------------------
    %שלב 6: דחיסת תווים ומעקב אחר משך הזמן
    %-------------------------------------------------
    beatDuration = 0.5;                                                                    % נניח קצב של 120 BPM (60/120 = 0.5 שניות)
    compressed_notes = {};
    durations_windows = [];

    silence_threshold = 0.05;                                                              % ערך עוצמה מתחתיו נחשב שתיקה
    if ~isempty(detected_notes)
        current_note = detected_notes{1};
        current_duration = 1;

        for i = 2:length(detected_notes)
            current_magnitude = max(abs(S(:, i)));                                         % העוצמה בחלון הנוכחי
            if strcmp(detected_notes{i}, current_note) && current_magnitude > silence_threshold
                current_duration = current_duration + 1;                                   % אם אותו תו ואין שתיקה
            else                                                             
                compressed_notes{end+1} = current_note;                                    % אחרת: סוגרים תו ומתחילים חדש
                durations_windows(end+1) = current_duration;
                current_note = detected_notes{i};
                current_duration = 1;
            end
        end
                                                                                       
        compressed_notes{end+1} = current_note;                                             % הוספת התו האחרון
        durations_windows(end+1) = current_duration;
    end

    %---------------------------------------------------
    % שלב 7: איחוד תווים חוזרים ומפוצלים
    %---------------------------------------------------
    min_duration_seconds = 0.1;                                                             % סף זמן מינימלי לתו
    i = 1;
    while i < length(compressed_notes)
        duration_seconds = durations_windows(i) * (window - overlap) / sampleRate;          % חישוב הזמן של התו בשניות
        if duration_seconds < min_duration_seconds                                          % אם הזמן קטן מהסף                                                                            
            if i < length(compressed_notes) && strcmp(compressed_notes{i}, compressed_notes{i+1})
                durations_windows(i+1) = durations_windows(i+1) + durations_windows(i);  
                compressed_notes(i) = [];       
                durations_windows(i) = [];
                continue;      
            end
        end
        i = i + 1;
    end
    %---------------------------------------------------
    % שלב 8: סיווג התווים לפי המשך שלהם 
    %---------------------------------------------------
    final_classified_notes = {};
    final_durations_seconds = [];

    for i = 1:length(compressed_notes)
        note = compressed_notes{i};
        duration_seconds = durations_windows(i) * (window - overlap) / sampleRate;               % חישוב זמן בשניות

        if duration_seconds > 0.09
            halfNoteDurationThreshold = beatDuration * 1.8;                                      % סף לזיהוי תו חצי 
            quarterNoteDuration = beatDuration * 0.9;                                            % משך זמן משוער של רבע

            if duration_seconds >= halfNoteDurationThreshold
                final_classified_notes{end+1} = note;
                final_durations_seconds(end+1) = quarterNoteDuration;
                final_classified_notes{end+1} = note;
                final_durations_seconds(end+1) = quarterNoteDuration;
            else
                final_classified_notes{end+1} = note;
                final_durations_seconds(end+1) = duration_seconds;
            end
            %disp(['תו: ', note, ' (', num2str(duration_seconds), ' שניות)']);
        end
    end

    %-------------------------------------------------------
    % שלב 9: כתיבת התוצאות לקובץ classified_notes.txt 
    %-------------------------------------------------------
    [fileDir, ~, ~] = fileparts(filePath);
    outputFileClassified = fullfile(fileDir, 'classified_notes.txt');
    fileID = fopen(outputFileClassified, 'w');
    if fileID == -1
        disp('שגיאה: לא ניתן לפתוח את הקובץ לכתיבה.');
        return;
    end

    fprintf(fileID, 'תווים ומשכי זמן (בשניות)\n');

    for i = 1:length(final_classified_notes)                                               
        duration_seconds = final_durations_seconds(i);
        fprintf(fileID, 'תו: %s, משך: %.2f שניות\n', final_classified_notes{i}, duration_seconds);
    end

    fclose(fileID);
    disp(['סיווג התווים נכתב לקובץ: ', outputFileClassified]);

    %-----------------------------------------------
    % שלב 10: יצירת מבנה JSON עם התוצאות 
    %-----------------------------------------------
    output.notes = struct('note', final_classified_notes', 'duration', num2cell(final_durations_seconds');

    [~, fileName, ~] = fileparts(filePath);                                                           % יצירת נתיב לקובץ JSON
    jsonOutputPath = fullfile(pwd, 'uploads', 'classified_notes.json');
    if ~exist('uploads', 'dir')
        mkdir('uploads');
        disp('תיקיית uploads נוצרה.');
    end
    
    fid = fopen(jsonOutputPath, 'w');                                                                  % כתיבת התוצאה לקובץ JSON
    if fid == -1
        disp('שגיאה: לא ניתן לפתוח את הקובץ _classified_notes.json לכתיבה.');
        return;
    end

    fwrite(fid, jsonencode(output));
    fclose(fid);
    disp(['הנתונים נכתבו לקובץ: ', jsonOutputPath]);
end