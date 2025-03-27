%% Sezione - Caricamento dati e Setup

surf_id = 5; % scelta superfice: 1 o 5

load('./Challenge_Problems/Data_Set_1_test.mat'); % caricamento set traiettorie

% caricamento set guasti
if surf_id == 1
    load('./Challenge_Problems/Data_Set_4_s1.mat');
elseif surf_id == 5
    load('./Challenge_Problems/Data_Set_4_s5.mat');
end

% directory per il salvataggio dei dati (aggiungere \ o / alla fine del percorso)
output_dir = './data/';

% setup velivolo
userStruct.variants.refInputType = 4; % ref input: 4 = Piecewise Bezier
userStruct.variants.fmType       = 2; % fore/moment model: 1 = Aerodynamic model, 1 = s-function, 2 = polynomial
userStruct.variants.propType     = 4; % propulsor model: 4 = First order fail
userStruct.variants.actType      = 4; % aero effector model: 4 = First order fail

model = 'GUAM'; % selezione modello

%% Sezione - Preparazione Scenario

num_record_classe = 1; % numero di voli da simulare
rnd_seed = 1; % random seed
rng(rnd_seed); 
fail_type = 1; % tipo di guasto: 0 - no guasto, 1 - hold_last, 2 - pre_scale, 3 - post_scale, 8 - control_reversal

if fail_type % se lo scenario e' con guasto scelgo la superfice
    surf_label = surf_id;
    % array indice traiettorie e guasti
    iter_array = findIndices(Surf_FailInit_Array, fail_type, surf_label);
else
    surf_label = 0;
    iter_array = randi([1, 3000], 1, 2*num_record_classe); % seleziona traiettorie random
end

sim_count = 1; % contatore per le simulazioni avvenute con successo
index = 1; % indice traiettoria e guasto

%% Sezione - Simulazione Voli

while sim_count <= num_record_classe

    traj_run_num = iter_array(index); % Select the desired own-ship trajectory number
    fail_run_num = iter_array(index); % Select the corresponding failure case number 

    formatSpec = 'Indice array: %d, Id traiettoria: %d.\n';
    fprintf(formatSpec, index, traj_run_num);
    
    % setup traiettoria
    wptsX_cell = own_traj(traj_run_num, 1);
    wptsY_cell = own_traj(traj_run_num, 2);
    wptsZ_cell = own_traj(traj_run_num, 3);
    time_wptsX_cell = own_traj(traj_run_num, 4);
    time_wptsY_cell = own_traj(traj_run_num, 5);
    time_wptsZ_cell = own_traj(traj_run_num, 6);    
    target.RefInput.Bezier.waypoints = {wptsX_cell{1}, wptsY_cell{1}, wptsZ_cell{1}};
    target.RefInput.Bezier.time_wpts = {time_wptsX_cell{1}, time_wptsY_cell{1}, time_wptsZ_cell{1}};
    target.RefInput.Vel_bIc_des    = [wptsX_cell{1}(1,2) wptsY_cell{1}(1,2) wptsZ_cell{1}(1,2)];
    target.RefInput.pos_des        = [wptsX_cell{1}(1,1) wptsY_cell{1}(1,1) wptsZ_cell{1}(1,1)];
    target.RefInput.chi_des        = atan2(wptsY_cell{1}(1,2),wptsX_cell{1}(1,2));
    target.RefInput.chi_dot_des    = 0;
    target.RefInput.trajectory.refTime = [0 time_wptsX_cell{1}(end)];
    
    simSetup % setup modello
    
    if fail_type
        % setup scenario guasto
        SimPar.Value.Fail.Surfaces.FailInit     = Surf_FailInit_Array(:, fail_run_num); % tipo guasto
        SimPar.Value.Fail.Surfaces.InitTime     = Surf_InitTime_Array(:, fail_run_num); % tempo start guasto
        init_time                               = SimPar.Value.Fail.Surfaces.InitTime(find(SimPar.Value.Fail.Surfaces.InitTime ~= 0, 1, 'first'));
        fprintf('Inizio guasto: %5.2f sec \n', init_time);
        SimPar.Value.Fail.Surfaces.StopTime     = Surf_StopTime_Array(:, fail_run_num); % tempo stop guasto
        stop_time                               = SimPar.Value.Fail.Surfaces.StopTime(find(SimPar.Value.Fail.Surfaces.StopTime ~= 0, 1, 'first'));
        fprintf('Fine guasto: %5.2f sec \n', stop_time);
        SimPar.Value.Fail.Surfaces.PreScale     = Surf_PreScale_Array(:, fail_run_num); % fattore pre-scale
        SimPar.Value.Fail.Surfaces.PostScale    = Surf_PostScale_Array(:, fail_run_num); % fattore post-scale
    end
    
    if fail_type
        SimIn.stopTime = stop_time; % la simulazione termina alla fine del guasto
    else
        SimIn.stopTime = 60; % se non c'e' guasto, lasimulazione terminera' dopo 60 secondi
        init_time = 0;
        stop_time = 60;
    end

    open(model);

    try
        fprintf('Avvio simulazione...\n')
        sim(model); % avvio simulazione
        fprintf('Volo terminato. Salvataggio dati in corso...\n');
        % selezione dei dati 
        flight_data = collectData(logsout, fail_type, init_time, stop_time, surf_label, rnd_seed);
        % salvataggio dati
        saveData(flight_data, fail_run_num, fail_type, surf_label, output_dir);
        fprintf('Conclusa con successo la simulazione numero: %d.\n', sim_count);
        sim_count = sim_count + 1 ;
    catch ME
        % Alcuni guasti/traiettorie generano un errore nel simulatore, non permettendo
        % di salvare i dati di volo
        fprintf('Errore durante la simulazione.\n');
        disp(ME);
        fprintf('Dati non salvati. Proseguo...\n')
        index = index + 1; % cambio traiettoria
        continue;
    end
    index = index + 1; % cambio traiettoria
end
fprintf('Fine esperimento.\n');

%% Sezione - Funzioni

function indices = findIndices(array, failId, surfId)
% FINDINDICES Resituisce indici dello scenario di guasto fornito.
%
%   colIndices = FINDINDICES(array, targetValue, surfId) 
%       restituisce la lista dei failId, in posizione surfId, pescati
%       randomicamente da array
%
%   Input:
%       array - Lista guasti (array)
%       failId - Tipo di guasto (int)
%       surfId - Id superfice di controllo (int)
%
%   Output:
%       indices - Lista dei failId in posizione surfId (array)

    if isempty(array)
        indices = [];
        return;
    end

    row = array(surfId, :);
    array = find(row == failId);
    randomIndices = randperm(length(array));
    indices = array(randomIndices);
end

function outputData = collectData(rawData, failId, tStart, tEnd, surfId, seed)
% COLLECTDATA Resituisce la tabella contenente i dati di volo.
%
%   outputData = COLLECTDATA(output, fail_type, tStart, tEnd, surfId, seed) 
%       restituisce la tabella relativa ai dati di volo (variabili di
%       controllo e sensoi) con aggiunta di rumore bianco gaussiano, con
%       rapporto segnale/rumore variabile, successivamente filtrato.
%
%   Input:
%       rawData - Dati in output del simulatore (struct)
%       failId - Tipo di guasto (int)
%       tStart - Tempo di inizio del guasto (float)
%       tEnd - Tempo di fine del guasto (float)
%       surfId - Id superfice di controllo (int)
%
%   Output:
%       outputData - Tabella contenente i dati di volo elaborati (table)

    rng(seed); 
    out_data = rawData{1}.Values;
    time = out_data.Time;
    % placeholder per label guasto e superfice
    fail = zeros*ones(size(time.Data, 1), 1);
    surf = zeros*ones(size(time.Data, 1), 1);
    sensor_data = out_data.Vehicle.Sensor; % dati dai sensori
    fields = fieldnames(sensor_data); % nomi campi sensori
    for i = 1:numel(fields)
        SNR_dB = randi([10, 30]); % selezione rapporto segnale/rumore [dB]
        curr_field = fields{i};
        if ~(strcmp(curr_field, 'Euler'))
            curr_data = sensor_data.(curr_field).Data;
            noisy_values = awgn(curr_data, SNR_dB, 'measured'); % aggiunta rumore
            noisy_sensor_data.(curr_field) = noisy_values; % aggiunta dati
        else
            euler_fields = fieldnames(sensor_data.(curr_field));
            for j = 1:numel(euler_fields)
                SNR_dB = randi([10, 30]); % selezione rapporto segnale/rumore [dB]
                sub_field = euler_fields{j};
                curr_data = sensor_data.(curr_field).(sub_field).Data;
                noisy_values = awgn(curr_data, SNR_dB, 'measured'); % aggiunta rumore
                noisy_sensor_data.(sub_field) = noisy_values; % aggiunta dati
            end
        end
    end

    % filtraggio del rumore nei dati dei sensori
    outputData = filterNoise(noisy_sensor_data);
    
    control_data = out_data.Control.Cmd; % dati variabili di controllo
    fields = fieldnames(control_data); % nomi campi cmd
    for i = 1:numel(fields)
        curr_field = fields{i};
        % il sumlatore lascia a valore '1' i seguenti campi, che vengono
        % quindi esclusi
        if ~(strcmp(curr_field, 'EnginePwr')) && ~(strcmp(curr_field, 'CtrlSurfacePwr')) && ~(strcmp(curr_field, 'GearCmd'))
            curr_data = control_data.(curr_field).Data;
            outputData.(curr_field) = curr_data; % aggiunta dati
        end
    end

    % aggiunta colonna etichette
    if failId
        idxInterval = (time.Data >= tStart) & (time.Data <= tEnd);
        fail(idxInterval) = failId;
        surf(idxInterval) = surfId;
    end
    outputData.Label = fail;
    outputData.Surface = surf;
end

function outputSignals = filterNoise(noisyData)
% FILTERNOISE Resituisce la tabella contenente i dati di volo filtrati.
%
%   outputSignals = FILTERNOISE(noisyData) 
%       filtra i segnali rumorosi di noisyData e li inserisce in una
%       tabella. Utilizzo di un filtro passa-basso specificando frequenza
%       di taglio e di campionamento.
%
%   Input:
%       noisyData - Segnali rumorosi (table)
%
%   Output:
%       outputSignals - Tabella contenente i segnali filtrati (table)

    Ts = 0.005; % tempo di campionamento del simulatore
    Fs = 1/Ts; % frequenza di campionamento
    Fb = 5; % frequenza di taglio
    fields = fieldnames(noisyData);
    for i = 1:numel(fields)
        curr_field = fields{i};
        filter = lowpass(noisyData.(curr_field), Fb, Fs); % filtro passa-basso
        outputSignals.(curr_field) = filter; % aggiunta segnale filtrato
    end
end

function saveData(data, trajId, failId, surfId, outputDir)
% SAVEDATA(data, trajId, failId, surfId, outputDir) Salva i dati di volo 
% in una tabella .csv nella directory specificata. Il nome del file 
% riportera' l'id della traiettoria, del guasto e della superfice interessata.
%
%   Input:
%       data - Dati di volo da salvare (table)
%       trajId - Id traiettoria relativa ai dati (int)
%       failId - Tipo di guasto (int)
%       surfId - Id superfice di controllo (int)
%       outputDir - Directory in cui salvare il file (str)

    fields = fieldnames(data); % nomi dei campi
    outputData = []; % placeholder dati finali
    header = {}; % inizializzazione header
    for i = 1:numel(fields)
        fieldName = fields{i};
        fieldData = data.(fieldName); % estrazione dati
        
        if isnumeric(fieldData) || islogical(fieldData) || iscell(fieldData)
            numColumns = size(fieldData, 2); % numero colonne del campo
            for j = 1:numColumns
                header{end+1} = sprintf('%s_%d', fieldName, j); % nome colonna
            end
            outputData = [outputData, fieldData]; % concatenazione dati
        else
            error('Formato campo %s non supportato.', fieldName);
        end
    end
    % creazione dati
    outputTable = array2table(outputData, 'VariableNames', header);
    % nome del file
    file_name = [outputDir, 'volo_id', num2str(trajId), '_f', ...
        num2str(failId), '_s', num2str(surfId), '.csv'];
    % salvataggio tabella in file CSV
    writetable(outputTable, file_name);
end