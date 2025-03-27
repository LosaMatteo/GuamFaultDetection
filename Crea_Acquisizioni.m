%% Creazione finestre di acquisizione

% percorso dei file relativi ai dati di volo
path = './data';
files = dir(fullfile(path, '*.csv'));

guamDataset = table; % tabella dati finale
newData = table; % tabella dati parziale
seconds = 1.5; % durata acquisizione (secondi)
samples = 1; % acquisizioni per file
rng(51) % random seed
disp('Creando il dataset...')

for i = 1:length({files.name})
    fileName = fullfile(path, files(i).name);
    Data = readtable(fileName);
    newData = creaDataset(Data, samples, seconds);
    guamDataset = [guamDataset; newData];
end

newRowOrder = randperm(height(guamDataset)); 
guamDataset = guamDataset(newRowOrder, :);


%% Funzioni per la creazione del dataset

function dataTable = creaDataset(Data, numSample, seconds)
% CREADATASET Resituisce una tabella contenente il numero di acquisizoni 
% specificate dall'utente per ogni segnale, sotto forma di timetable.
%
%   dataTable = CREADATASET(Data, numSample, seconds) 
%       restituisce la tabella contenente le acquisizioni dei segnali di
%       volo. La tabella ha una riga per acquisizone, pescata
%       randomicamente, della durata specificata in secondi specificata
%       dall'utente. Ogni acuisizione e' rappresentata da una time table.
%       Le colonne sono composte dai segnali e dalle etichette di guasto 
%       e superfice.
%
%   Input:
%       Data - Dati di volo (table)
%       numSample - Numero di acquisizioni per file (int)
%       seconds - Durata in secondi delle finestre di acquiszione (float)
%
%   Output:
%       dataTable - Tabella contenente le acquisizioni ottenute (table)

    Data_filtered = Data(~(Data.Label_1 == 0), :); % selezione dei campioni con guasto
    if isempty(Data_filtered) % se non c'e' guasto
        Data_filtered = Data(Data.Label_1 == 0, :); % selezione dei campioni senza guasto
    end

    dt = 0.005; % tempo di campionamento
    numRowsToSelect = seconds/dt;
    numRowsTotal = height(Data_filtered);
    maxStartIndex = numRowsTotal - numRowsToSelect + 1;

    partialData = table;

    colNames = Data_filtered.Properties.VariableNames; % nomi delle colonne
    failCode = Data_filtered.Label_1(end); % label guasto
    surfId = Data_filtered.Surface_1(end); % label superfice

    if failCode == 3
        failCode = 2; % accorpamento guasto pre-scale e post-scale             
    end

    for i = 1:numSample
        startIndex = randi([1, maxStartIndex]);
        selectedIndices = startIndex:(startIndex + numRowsToSelect - 1);
        
        % selezione sotto-tabella relativa all'acquisizione
        Data_selected = Data_filtered(selectedIndices, :);
        
        newTimeVector = (0:numRowsToSelect-1)' * dt; % vettore dei tempi
    
        tsArray = cell(1, width(Data_selected));
    
        currData = table;
        
        % costruzione delle timetable
        for j = 1:width(Data_selected)
            tsArray{j} = timeseries(Data_selected{:, j}, newTimeVector);
            tsArray{j}.Name = colNames{j};
            TT = timeseries2timetable(tsArray{j});
            currData.(colNames{j}) = {TT}; 
        end
        currData.failCode = int2str(failCode); % label id guasto
        currData.surfId = int2str(surfId); % label id superfice
        partialData = [partialData; currData]; % dati parziali
    end  
    dataTable = partialData;
end
