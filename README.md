# Guam Fault Classification
Questo repository fornisce una pipeline completa per raccogliere ed elaborare dati di volo al fine di classificare diversi scenari di guasto in un contesto aeronautico per la Urbain Air Mobility.

L'obiettivo del progetto è quello di costruire un modello di classificazione diagnostico in grado di distinguere tra le varie tipologie di guasto che interessano le superfici di controllo del velivolo.

## Panoramica del Progetto
Il progetto utilizza un simulatore MATLAB/SIMULINK, originariamente sviluppato nel repository [Generic-Urban-Air-Mobility](https://github.com/nasa/Generic-Urban-Air-Mobility-GUAM), per generare scenari realistici di volo sotto diverse condizioni di guasto che possono interessare diverse superfici di controllo del velivolo. La classificazione finale consiste nell'utilizzo di *tre modelli* con *approccio a cascata*:
1. **Primo Modello**: classificherà il record tra scenario con guasto o senza guasto, indipendentemente dalla tipologia.
2. **Secondo Modello**: se il modello precedente ha predetto un guasto, il secondo dovrà predire quale superfice di controllo è stata interessata.
3. **Terzo Modello**: l'ultimo modello si occuperà di assegnare una tipologia al guasto che ha colpito il velivolo.

La pipeline del progetto prevede i seguenti step principali:

1. **Generazione Traiettorie e Guasti**: generazione di diverse traiettorie di volo e diversi scenari di guasto..
2. **Simulazione dei Voli**: simulazioni di volo in condizioni normali e di guasto.
3. **Raccolta ed Elaborazione dei Dati**: raccolta dei dati di volo con aggiunta e filtraggio di rumore bianco gaussiano, solo sui dati provenienti dai sensori, per simulare scenari di volo più realistici.
4. **Creazione delle Finestre Temporali**: selezione di una o più finestre temporali per volo, etichettate in base allo scenario di guasto del volo.
5. **Pulizia del Dataset**: correzione dei valori non validi con tecniche di imputazione, una volta estratte le feature nel tempo dei segnali campionati (nel nostro esperimento è stata utilizzata l'app *Diagnostic Feature Designer* di MATLAB).
6. **Feature Selection**: riduzione della dimensionalità con selezione delle feature.
7. **Costruzione del Classificatore**: addestramento di un modello di classificazione (approccio *Ensemble* con alberi decisionali) a seguito di un processo di ottimizzazione degli iperparametri.
8. **Test del Modello Finale**: test del modello finale su dati nuovi e visualizzazione dei risultati (*Matrice di Confusione* e *ROC Curve*).

## Requisiti
Il programma è stato testato con la versione **R2024b** di MATLAB.

Altre funzionalità necessarie:
- **Statistics and Machine Learning Toolbox**
- **Predictive Maintenance Toolbox**
- **Signal Processing Toolbox**

## Utilizzo
- Clonare il repository originale del simulatore [Generic-Urban-Air-Mobility](https://github.com/nasa/Generic-Urban-Air-Mobility-GUAM)
- All'interno della directory principale...FINIRE

## Step 1: Generazione Traiettorie e Guasti
Nel nostro esperimento sono stati considerati guasti di diversa categoria alla superfice 5, il *timone*, e alla superfice 1, posizionata nell'*ala sinistra* del velivolo. Lo script `Generate_Own_Traj.m` è stato utilizzato per generare un insieme randomico di 3000 traiettorie diverse. Per ognuna delle traiettorie, tramite lo script `Generate_Failures.m`, viene generato un guasto di una certa categoria, durata e intensità, alla superfice 1 e, ripetendo il procedimento, alla superfice 5. I file di output dei due script, `Data_Set_1.mat` e `Data_Set_4.mat`, contengono rispettivamente le informazioni sulle traiettorie e sui guasti generati.

Le tipologie di guasto disponibili sono le seguenti:

1. **Hold-Last**:  congela il valore di uscita dell’attuatore coinvolto a
quello dell’istante prima dell’insorgenza del guasto.
2. **Pre-Scale**: applica un valore di scala al segnale in ingresso al modello dell’attuatore.
3. **Post-Scale**: applica un valore di scala al segnale in uscita dall'attuatore.
4. **Control Reversal**: inverte il segnale in ingresso all'attuatore.

## Step 2: Simulazione Voli
Lo script `Simula_Voli.m`, utilizzando i file ottenuti nello step precedente, permette di selezionare il numero di voli da simulare per una certa tipologia di guasto (compreso quello in condizioni normali). Lo script pesca casualmente tra i failure generati quelli relativi allo scenario di guasto scelto e utilizzerà lo stesso indice per scegliere la traiettoria di riferimento per il volo, procedendo con le simulazioni fino a raggiungere il numero di voli stabilito. 

## Step 3: Raccolta ed Elaborazione Dati
Sempre nello script `Simula_Voli.m`, verranno raccolti i dati relativi alle variabili di controllo di motori e superfici e ai sensori, aggiungendo a questi ultimi del rumore bianco gaussiano con un rapporto segnale/rumore [dB] variabile tra 10 e 30. Il rumore sarà poi filtrato con un filtro passa-basso, specificando la frequenza di taglio, ottenendo i dati di volo finali. I risultati saranno salvati sotto forma di tabelle, in file `.csv`, nella directory `/data`.

## Step 4: Creazione Finestre Temporali
Tramite il file `Crea_Campioni.m` è possibile estrarre randomicamente delle finestre temporali dai singoli voli, a partire dai file `.csv` ottenuti, all'interno dell'intervallo di tempo in cui il guasto si è verificato. L'utente potrà specificare quante finestre temporali per volo estrarre e la loro durata in secondi. La finestra temporale scelta verrà utilizzata per catturare i dati di tutti i segnali di interesse. Lo script procederà poi a etichettare la singola finestra in base alla tipologia di guasto e alla superfice di controllo interessata.

## Step 5: Pulizia Dataset
Dopo aver estratto le feature nel tempo dei segnali per ogni finestra temporale, ottenendo un nuovo dataset (`trainingSetDFD.mat`), è possibile effettuare una pulizia dei valori non validi tramite il file `Clean_Table.m`. Questo script, tramite metodi di imputazione, produce la tabella `trainingSetDFDClean.mat`. 

## Step 6: Feature Selection
Nello script `Build_Model.m`, a partire dal dataset ottenuto nello step precedente, avviene la preparazione dei dati per l'addestramento e per il test, dove l'utente può scegliere la percentuale del dataset da riservare per il test. Con i dati rimanenti (quelli non scelti per il test), per ridurre la dimensionalità dei dati, è possibile valutare le feature attraverso i test *One-Way ANOVA* o *Kruskall-Wallis* e scegliere il numero di feature ordinate per punteggio da selezionare.

## Step 7: Costruzione Modello
Ancora nello script `Build_Model.m`, si procede con l'addestramento di un classificatore di tipo *ensemble* con *alberi decisionali*. La prima fase prevede la ricerca degli iperparametri ottimali per la minimizzazione dell'errore di classificazione, stimato tramite *k-fold cross-validation*. Alla fine del processo, verrà mostrata la matrice di confusione realtiva al modello cross-validato. Gli iperparametri ottimali restituiti vengono poi utilizzati per l'addestramento del modello finale.

## Step 8: Test Modello
Infine, sempre nel file `Build_Model.m`, si effettua il test del modello sulla porzione selezionata nello Step 6. Dopo le predizioni, verranno mostrate *Matrice di Confusione*, *ROC Curve* e *accuracy* generale.

## Nota
I procedimenti degli *step 6-7-8* sono stati ripetuti per la costruzione di tutti e tre i modelli previsti dall'approccio a cascata utilizzato.
