# Guam Fault Detection
Questo repository nasce dal progetto D1 - GENERIC URBAN AIR MOBILITY del corso di Manutenzione Preventiva per la Robotica e l'Automazione Intelligente, dell'Università Politecnica delle Marche, tenuto dal Prof. Alessandro Freddi.

Il progetto svolto fornisce una pipeline completa per la raccolta e l'elaborazione dei dati di volo con il fine di classificare diversi scenari di guasto in un contesto aeronautico per la Urbain Air Mobility.

L'obiettivo del progetto è quello di costruire un modello di classificazione diagnostico in grado di distinguere tra le varie tipologie di guasto che interessano le superfici di controllo del velivolo.

## Panoramica del Progetto
Il progetto utilizza un simulatore MATLAB/SIMULINK, originariamente sviluppato nel repository [Generic-Urban-Air-Mobility](https://github.com/nasa/Generic-Urban-Air-Mobility-GUAM), per generare scenari realistici di volo sotto diverse condizioni di guasto che possono interessare diverse superfici di controllo del velivolo. La classificazione finale consiste nell'utilizzo di *tre modelli* con *approccio a cascata*:
1. **Primo Modello**: classificherà il record tra scenario con guasto o senza guasto, indipendentemente dalla tipologia.
2. **Secondo Modello**: se il modello precedente ha predetto un guasto, il secondo dovrà predire quale superficie di controllo è stata interessata.
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
- Clonare il repository originale del simulatore, [Generic-Urban-Air-Mobility](https://github.com/nasa/Generic-Urban-Air-Mobility-GUAM).
- Scaricare questo repository.
- Copiare i file della cartella `Challenge_Problems` di questo repository nell'omonima cartella del repository originale.
- Copiare i restanti file e cartelle di questo repository nella directory `/Generic-Urban-Air-Mobility-GUAM` di quello originale.

## Struttura del repository
- **Challenge_Problems**: contiene i dati relativi alle traiettorie e i guasti generati (insieme allo script per generarli).
- **data**: contiene alcuni file di volo di esempio in formato `.csv` da cui è possibile effettuare delle acquisizione dei segnali.
- **Dataset**: contiene i dataset ottenuti dalle diverse fasi dell'esperimento: dataset con finestre temporali e dataset con feature nel tempo (**DFD**) per i tre modelli.
- **Models**: contiene i modelli di classificazione ottenuti con relativi risultati e parametri utilizzati (file `info.txt`).
- **Script ausiliari**: nella cartella principale, file per simulazione dei voli, creazione delle acquisizioni, del dataset, dei classificatori e test di questi ultimi.

## Step 1: Generazione Traiettorie e Guasti
Nel nostro esperimento sono stati considerati guasti di diversa categoria alla superficie 5, il *timone*, e alla superficie 1, posizionata nell'*ala sinistra* del velivolo. Lo script `Generate_Own_Traj.m`, del repository originale, è stato utilizzato per generare un insieme randomico di 3000 traiettorie diverse. Per ognuna delle traiettorie, tramite lo script `Challenge_Problems/Generate_Failures_Modificato.m`, viene generato un guasto di una certa categoria, durata e intensità, alla superficie 1 e, ripetendo il procedimento, alla superficie 5. I file di output dei due script, `Challenge_Problems/Data_Set_1_Test.mat`, `Challenge_Problems/Data_Set_4_s1.mat` e `Challenge_Problems/Data_Set_4_s5.mat`, contengono rispettivamente le informazioni sulle traiettorie e sui guasti generati.

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
Tramite il file `Crea_Acquisizioni.m` è possibile estrarre randomicamente delle finestre temporali dai singoli voli, a partire dai file `.csv` ottenuti, all'interno dell'intervallo di tempo in cui il guasto si è verificato. L'utente potrà specificare quante finestre temporali per volo estrarre e la loro durata in secondi. La finestra temporale scelta verrà utilizzata per catturare i dati di tutti i segnali di interesse. Lo script procederà poi a etichettare la singola finestra in base alla tipologia di guasto e alla superficie di controllo interessata. **Nota**: per limiti di dimensione non è stato possibile caricare il dataset completo come file singolo; questo è stato diviso in tre tabelle (`guamDataset_NoFault.mat`, `guamDataset_Surf1.mat` e `guamDataset_Surf5.mat`, nella cartella `Dataset`) che possono essere unite per proseguire con i passaggi successivi.

## Step 5: Pulizia Dataset
Dopo aver estratto le feature nel tempo dei segnali per ogni finestra temporale si ottiene nuovo dataset (`Dataset/guamDatasetDFD.mat`, nel nostro caso), a partire dal quale vengono creati i tre diversi dataset per i modelli che verranno addestrati tramite lo script `Crea_Dataset.m`. Successivamente, viene effettuata una pulizia dei valori non validi con metodi di imputazione, producendo una nuova tabella. Questa funzionalità è presente nello script `Costruisci_Modello.m`.

## Step 6: Feature Selection
Sempre nello script `Costruisci_Modello.m`, a partire dal dataset ottenuto nello step precedente, avviene la preparazione dei dati per l'addestramento e per il test, dove l'utente può scegliere la percentuale del dataset da riservare per il test. Con i dati rimanenti (quelli non scelti per il test), per ridurre la dimensionalità dei dati, è possibile valutare le feature attraverso i test *One-Way ANOVA* o *Kruskall-Wallis* e scegliere il numero di feature ordinate per punteggio da selezionare.

## Step 7: Costruzione Modello
Ancora nello script `Costruisci_Modello.m`, si procede con l'addestramento di un classificatore di tipo *ensemble* con *alberi decisionali*. La prima fase prevede la ricerca degli iperparametri ottimali per la minimizzazione dell'errore di classificazione, stimato tramite *k-fold cross-validation*. Alla fine del processo, verrà mostrata la matrice di confusione realtiva al modello cross-validato. Gli iperparametri ottimali restituiti vengono poi utilizzati per l'addestramento del modello finale.

## Step 8: Test Modello
Infine, nel file `Costruisci_Modello.m`, si effettua il test del modello sulla porzione selezionata nello Step 6. Dopo le predizioni, verranno mostrate *Matrice di Confusione*, *ROC Curve* e *accuracy* generale. Nello script `Test_Modelli.m` è presente un esempio di classificazione con l'utilizzo a cascata dei tre modelli. Questo esempio utilizza il set di dati `Models/guamTestsetProvaDFD.mat` come prova.

## Nota
Nel nostro esperimento sono stati accorpati i guasti Pre-Scale e Post-Scale in un unica classe per migliorare la classificazione generale.
I procedimenti degli *step 5-6-7-8* sono stati ripetuti per la costruzione di tutti e tre i modelli previsti dall'approccio a cascata utilizzato.
