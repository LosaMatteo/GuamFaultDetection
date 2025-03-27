% Script per creare i dataset finali da fornire agli algoritmi di
% classificazione. I dataset vengono creati a partire dalle tabelle
% contenenti le feature nel tempo dei segnali e relative etichettature.

% carica il file .mat del dataset con feature estratte
load('Dataset/guamDatasetDFD.mat'); % aggiustare il percorso se necessario

% creazione dataset per il primo modello (guasto/no guasto)
no_fault = guamDatasetDFD(strcmp(guamDatasetDFD.failCode, "0"), :);
no_fault(:, "surfId") = [];
fault = guamDatasetDFD(~strcmp(guamDatasetDFD.failCode, "0"), :);
fault_1 = fault;
fault_1(:, "surfId") = [];
fault_1.failCode(fault_1.failCode ~= 0) = "1";
datasetDFD_1 = [no_fault; fault_1];
colNames = datasetDFD_1.Properties.VariableNames;
idx = strcmp(colNames, 'failCode');
colNames(idx) = [];
newOrder = [colNames, {'failCode'}];
datasetDFD_1 = datasetDFD_1(:, newOrder); % dataset finale

% creazione dataset per il secondo modello (superficie 1 o superficie 5)
fault_2 = fault;
fault_2(:, "failCode") = [];
datasetDFD_2 = fault_2;
colNames = datasetDFD_2.Properties.VariableNames;
idx = strcmp(colNames, 'surfId');
colNames(idx) = [];
newOrder = [colNames, {'surfId'}];
datasetDFD_2 = datasetDFD_2(:, newOrder); % dataset finale

% creazione dataset per il terzo modello (tipologia guasto)
fault_3 = fault;
fault_3(:, "surfId") = [];
datasetDFD_3 = fault_3; 
colNames = datasetDFD_3.Properties.VariableNames;
idx = strcmp(colNames, 'failCode');
colNames(idx) = [];
newOrder = [colNames, {'failCode'}];
datasetDFD_3 = datasetDFD_3(:, newOrder); % dataset finale