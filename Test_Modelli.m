%% Pulizia dei valori non validi della tabella

load('Models/guamTestsetProvaDFD.mat'); % caricamento del testset

testsetDFDClean = replaceNonValidValues(testsetDFD); % inserire il nome corretto della tabella

%% Preparazione dati
XTest = testsetDFDClean(:, 3:end);

YTest_1 = testsetDFDClean(:, 1);
YTest_1{:, :}(~strcmp(YTest_1{:, :}, "0")) = "1"; % labels per modello 1 (guasto/no guasto)
YTest_2 = testsetDFDClean(~strcmp(testsetDFDClean{:, 2}, "0"), 2); % labels per modello 2 (id superfice)
YTest_3 = testsetDFDClean(~strcmp(testsetDFDClean{:, 1}, "0"), 1); % labels per modello 3 (id guasto)

% caricamento dei classificatori
load('Models/Model_1/guamModel_1.mat');
load('Models/Model_2/guamModel_2.mat');
load('Models/Model_3/guamModel_3.mat');

%% Test modelli

j = 1;
for i = 1:height(XTest)
    fprintf("\nNuova predizione.\n");
    [YPred_1, ~] = predict(Model_1, XTest(i, :)); % guasto/no guasto
    if YPred_1
        [YPred_2, ~] = predict(Model_2, XTest(i, :)); % superficie
        [YPred_3, ~] = predict(Model_3, XTest(i, :)); % tipologia guasto
        fprintf("Lo scenario predetto e' guasto alla superfice %d", YPred_2);
        fprintf(" di tipo %d.\n", YPred_3);
    else
        fprintf("Lo scenario predetto e' %d", YPred_1);
        fprintf(", ovvero senza guasto.\n");
    end
    % verfica dello scenario corretto
    if str2double(YTest_1{i, :})
        fprintf("Lo scenario corretto e' %s", YTest_1{i, :});
        fprintf(", ovvero guasto alla superfice %s", YTest_2{j, :});
        fprintf(" di tipo %s.\n", YTest_3{j, :});
        j = j + 1;
    else
        fprintf("Lo scenario corretto e' %s", YTest_1{i, :});
        fprintf(", ovvero senza guasto.\n");
    end
end

%% Funzione per pulizia della tabella

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