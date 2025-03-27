%% Pulizia dei valori non validi della tabella

% inserire il nome corretto della tabella gia' caricata nella workspace
datasetDFDClean = replaceNonValidValues(datasetDFD_2);

%% Parametri di input per l'addestramento
close all;

rng(4); % seed di estrazione per la riproducibilita'

Dataset = datasetDFDClean;
CondVar = 'surfId'; % nome label ('failCode' o 'surfId')

testRatio = 0.15; % porzione per il test set
kFolds = 5; % k-fold cross-validation

anovaTest = true; % true per anova test, false per kruskal-wallis test
numTopFeatures = 30; % numero di top feature da selezionare

%% Preparazione dati

if ischar(Dataset.(CondVar))
    Dataset.(CondVar) = str2double(cellstr(Dataset.(CondVar)));
end

labels = Dataset.(CondVar);

cvHoldout = cvpartition(labels, 'HoldOut', testRatio); % estrazione test set

trainFixedIdx = training(cvHoldout);
testFixedIdx = test(cvHoldout);

X = Dataset(trainFixedIdx, 1:end-1); % training
XTest = Dataset(testFixedIdx, 1:end-1); % test

Y = labels(trainFixedIdx, end); % training
YTest = labels(testFixedIdx, end); % test

%% Ottimizzazione iperparametri per la selezione dei predittori

% ranking delle feature
if anovaTest
    sortedFeatureNames = featureRankingAnova(X, array2table(Y));
else
    sortedFeatureNames = featureRankingKruskalWallis(X, array2table(Y));
end    

% selezione dei predittori
selectedFeatures = sortedFeatureNames(1:numTopFeatures);
X = X(:, selectedFeatures);
XTest = XTest(:, selectedFeatures);

%% Ottimizzazione iperparametri con feature selezionate

cvKFold = cvpartition(Y, 'KFold', kFolds); % k-fold cross-validation

% iperparametri da ottimizzare
hyperparam = {'Method', ...
    'LearnRate', ...
    'NumLearningCycles', ...
    'MaxNumSplits', ...
    'NumVariablesToSample'};

tree = templateTree('Reproducible', true); % componente dell'esemble

% la funzione di acquisizione e' impostata per consentire la 
% riproducibilita' del processo di ottimizzazione
OptMdl = fitcensemble(X, Y, 'OptimizeHyperparameters', hyperparam, ...
    'Learners', tree, ...
    'HyperparameterOptimizationOptions', ... 
    struct('AcquisitionFunctionName', 'expected-improvement-plus', ...
                                                'MaxObjectiveEvaluations', 30, ...
                                                'CVPartition', cvKFold, ...
                                                'Verbose', 1));

% lettura degli iperparametri ottimali
optHyperparam_train = OptMdl.HyperparameterOptimizationResults.XAtMinObjective;

% costruzione modello con iperparametri ottimali
if isnan(optHyperparam_train.NumVariablesToSample)
    tree = templateTree("Reproducible", true, ... 
        "MaxNumSplits", optHyperparam_train.MaxNumSplits);
else
    tree = templateTree("Reproducible", true, ...
        "MaxNumSplits", optHyperparam_train.MaxNumSplits, ...
        "NumVariablesToSample", optHyperparam_train.NumVariablesToSample);
end

if isnan(optHyperparam_train.LearnRate) 
    Mdl = fitcensemble(X, Y, "Method", string(optHyperparam_train.Method), ...
        "Learners", tree, ...
        "NumLearningCycles", optHyperparam_train.NumLearningCycles, ...
        "CVPartition", cvKFold);
else
    Mdl = fitcensemble(X, Y, "Method", string(optHyperparam_train.Method), ...
        "Learners", tree, ...
        "LearnRate", optHyperparam_train.LearnRate, ...
        "NumLearningCycles", optHyperparam_train.NumLearningCycles, ...
        "CVPartition", cvKFold);
end

% risultati sulla validazione
YPredCV = kfoldPredict(Mdl);

numFolds = Mdl.KFold;

accuracyCV = zeros(numFolds, 1);

for i = 1:numFolds
    testIdx = (Mdl.Partition.test(i));  % indici del validation set per il fold i-esimo
    accuracyCV(i) = sum(YPredCV(testIdx) == Y(testIdx)) / sum(testIdx);
end

% lettura dell'accuracy media + varianza
meanAccuracy = mean(accuracyCV);
varAccuracy = var(accuracyCV);

fprintf('Mean Cross-Validation Accuracy: %.2f%% ± %.2f%%\n', meanAccuracy * 100, varAccuracy * 100);

% matrice di confusione
figure;
confusionchart(Y, YPredCV);
title('Cross-Validation Confusion Matrix');

%% Train validated model

% addestramento finale del modello validato
if isnan(optHyperparam_train.LearnRate) 
    FinalMdl = fitcensemble(X, Y, "Method", string(optHyperparam_train.Method), ...
        "Learners", tree, ...
        "NumLearningCycles", optHyperparam_train.NumLearningCycles);
else
    FinalMdl = fitcensemble(X, Y, "Method", string(optHyperparam_train.Method), ...
        "Learners", tree, ...
        "LearnRate", optHyperparam_train.LearnRate, ...
        "NumLearningCycles", optHyperparam_train.NumLearningCycles);
end

disp('Fine addestramento.')

%% Test model

% risultati sul test set
[YPred_test, scores] = predict(FinalMdl, XTest);
% calcolo accuracy
accuracy = sum(YPred_test == YTest) / numel(YTest);
fprintf('Number of predictions: %d\n', numel(YTest));
fprintf('Test accuracy: %.2f%% \n', 100*accuracy);

figure; % matrice di confusione
confusionchart(YTest, YPred_test);
title('Test Confusion Matrix');

classNames = FinalMdl.ClassNames; 

numClasses = numel(classNames);

figure; % roc curve
hold on;

legendEntries = cell(numClasses,1);

for i = 1:numClasses

    scores_i = scores(:, i);
    class_i  = classNames(i); 

    [Xroc, Yroc, ~, AUC] = perfcurve(YTest, scores_i, class_i);

    plot(Xroc, Yroc, 'LineWidth', 1.5);

    legendEntries{i} = sprintf('%s (AUC=%.3f)', string(class_i), AUC);
end

xlabel('False Positive Rate');
ylabel('True Positive Rate');
title('ROC Curve multi-class (One-vs-Rest)');
legend(legendEntries, 'Location', 'best');
grid on;
hold off;

%% Funzione per pulizia della tabella e ranking delle feature

function dataTable = replaceNonValidValues(dataTable)
    % REPLACENONVALIDVALUES Restituisce la tabella ripulita, tramite metodi 
    % di implicazione, di valori non validi (NaN, -Inf e Inf).
    %
    %   dataTable = REPLACENONVALIDVALUES(dataTable) 
    %       restituisce la tabella in cui si sono sostituiti gli elementi
    %       NaN, -Inf e Inf con la media della colonna (feature), il valore
    %       minimo e il valore massimo, rispettivamente.
    %
    %   Input:
    %       dataTable - Tabella di input (table)
    %
    %   Output:
    %       dataTable - Tabella senza valori non validi (table)

    for col = 1:width(dataTable)
        if isnumeric(dataTable{:, col})
            colData = dataTable{:, col};  % dati della colonna
            
            % sostituisce NaN con il valore medio per la colonna
            meanVal = mean(colData, 'omitnan');
            colData(isnan(colData)) = meanVal;
            
            % sostituisce -Inf con il minimo valore della colonna
            minVal = min(colData(~isinf(colData)), [], 'omitnan');
            colData(colData == -Inf) = minVal;
            
            % sostituisci Inf con il massimo valore della colonna
            maxVal = max(colData(~isinf(colData)), [], 'omitnan');
            colData(colData == Inf) = maxVal;
            
            % aggiornamento tabella
            dataTable{:, col} = colData;
        end
    end
end

function sortedFeatureNames = featureRankingKruskalWallis(X, Y)
    % FEATURERANKINGKRUSKALWALLIS Restituisce l'array delle feature in
    % ordine decrescente in base al punteggio ottenuto con il test
    % Kruskal-Wallis.
    %
    %   sortedFeatureNames = FEATURERANKINGKRUSKALWALLIS(X, Y) 
    %       restituisce l'array in cui le feature della tabella in input
    %       sono ordinate in modo decrescente in base al punteggio ottenuto
    %       con in test Kruskal-Wallis per il ranking delle feature.
    %
    %   Input:
    %       X - Tabella delle feature (table)
    %       Y - Tabella delle label (double array)
    %
    %   Output:
    %       sortedFeatureNames - Array ordinato delle feature (cell array)

    data = table2array(X);
    labels = table2array(Y);
    numFeatures = size(data, 2);
    scores = zeros(numFeatures, 1);

    for i = 1:numFeatures
        p = kruskalwallis(data(:, i), labels, 'off');
        scores(i) = -log10(p);
    end

    [~, sortedIdx] = sort(scores, 'descend');
    sortedFeatureNames = X.Properties.VariableNames(sortedIdx);

end

function sortedFeatureNames = featureRankingAnova(X, Y)
    % FEATURERANKINGANOVA Restituisce l'array delle feature in
    % ordine decrescente in base al punteggio ottenuto con il test
    % One-Way ANOVA.
    %
    %   sortedFeatureNames = FEATURERANKINGANOVA(X, Y) 
    %       restituisce l'array in cui le feature della tabella in input
    %       sono ordinate in modo decrescente in base al punteggio ottenuto
    %       con in test One-Way Anova per il ranking delle feature.
    %
    %   Input:
    %       X - Tabella delle feature (table)
    %       Y - Tabella delle label (double array)
    %
    %   Output:
    %       sortedFeatureNames - Array ordinato delle feature (cell array)

    data = table2array(X);
    labels = table2array(Y);

    numFeatures = size(data, 2);
    scores = zeros(numFeatures, 1);

    for i = 1:numFeatures
        p = anova1(data(:, i), labels, 'off');        
        scores(i) = -log10(p);
    end

    [~, sortedIdx] = sort(scores, 'descend');
    sortedFeatureNames = X.Properties.VariableNames(sortedIdx);

end

