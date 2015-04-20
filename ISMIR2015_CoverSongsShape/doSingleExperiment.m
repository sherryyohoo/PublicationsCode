%Perform an experiment on covers80
%for a particular choice of beatIdx1 and beatIdx2 for the tempos in the
%first group and the tempos in the second group, as well as the parameters
%NIters, K, and Alpha for PatchMatch and dim, BeatsPerWin
addpath('BeatSyncFeatures');
addpath('SequenceAlignment');
addpath('SimilarityMatrices');
addpath('PatchMatch');

%Make directory to hold the results if it doesn't exist
dirName = sprintf('Results_%i_%i_%g', dim, BeatsPerWin, Kappa);
if ~exist(dirName);
    mkdir(dirName);
end

%Initialize parameters for matching
list1 = 'coversongs/covers32k/list1.list';
list2 = 'coversongs/covers32k/list2.list';
files1 = textread(list1, '%s\n');
files2 = textread(list2, '%s\n');
N = length(files1);


%Run all cross-similarity experiments between songs and covers
fprintf(1, '\n\n\n');
disp('======================================================');
fprintf(1, 'RUNNING EXPERIMENTS\n');
fprintf(1, 'dim = %i, BeatsPerWin = %i, Kappa = %g\n', dim, BeatsPerWin, Kappa);
fprintf(1, 'beatIdx1 = %i, beatIdx2 = %i\n', beatIdx1, beatIdx2);
disp('======================================================');
fprintf(1, '\n\n\n');

DsOrig = cell(1, N);
ChromasOrig = cell(1, N);
disp('Precomputing self-similarity matrices for original songs...');
for ii = 1:N
    tic;
    song = load(['BeatSyncFeatures', filesep, files1{ii}, '.mat']);
    fprintf(1, 'Getting self-similarity matrices for %s\n', files1{ii});
    DsOrig{ii} = single(getBeatSyncDistanceMatrices(song.allMFCC{beatIdx1}, ...
        song.allSampleDelaysMFCC{beatIdx1}, song.allbts{beatIdx1}, dim, BeatsPerWin));
    ChromasOrig{ii} = song.allBeatSyncChroma{beatIdx1};
    toc;
end

ScoresChroma = inf*ones(N, N); %Chroma by itself
ScoresMFCC = inf*ones(N, N); %MFCC by itself
Scores = inf*ones(N, N); %Combined
MinTransp = zeros(N, N); %Transposition that led to the lowest score
MinTranspCombined = zeros(N, N);

%Now loop through the cover songs
for jj = 1:N
    fprintf(1, 'Comparing cover song %i of %i\n', jj, N);
    tic
    song = load(['BeatSyncFeatures', filesep, files2{jj}, '.mat']);
    fprintf(1, 'Getting self-similarity matrices for %s\n', files2{jj});
    thisDs = single(getBeatSyncDistanceMatrices(song.allMFCC{beatIdx2}, ...
        song.allSampleDelaysMFCC{beatIdx2}, song.allbts{beatIdx2}, dim, BeatsPerWin));
    ChromaY = song.allBeatSyncChroma{beatIdx2};

    thisMsMFCC = cell(N, 1);
    for ii = 1:N
        %Step 1: Compute MFCC Self-Similarity features
        %Precompute L2 cross-similarity matrix and find Kappa percent mutual nearest
        %neighbors
        CSM = bsxfun(@plus, dot(DsOrig{ii}, DsOrig{ii}, 2), dot(thisDs, thisDs, 2)') - 2*(DsOrig{ii}*thisDs');
        MMFCC = groundTruthKNN( CSM, round(size(CSM, 2)*Kappa) );
        MMFCC = MMFCC.*groundTruthKNN( CSM', round(size(CSM', 2)*Kappa) )';
        ScoresMFCC(ii, jj) = sqrt(prod(size(MMFCC)))/swalignimp(double(full(MMFCC)));
        
        %Step 2: Compute transposed chroma delay features
        ChromaX = ChromasOrig{ii};
        ChromaX = getBeatSyncChromaDelay(ChromaX, BeatsPerWin, 0);
        allScoresChroma = zeros(1, size(ChromaY, 2));
        allScoresCombined = zeros(1, size(ChromaY, 2));
        for oti = 0:size(ChromaY, 2) - 1 
            %Transpose chroma features
            thisY = getBeatSyncChromaDelay(ChromaY, BeatsPerWin, 0);
            %Precompute L2 cross-similarity matrix and find Kappa percent mutual nearest
            %neighbors
            CSMChroma = bsxfun(@plus, sum(ChromaX.^2, 2), sum(thisY.^2, 2)') - 2*ChromaX*thisY';
            MChroma = groundTruthKNN( CSMChroma, round(size(CSMChroma, 2)*Kappa) );
            MChroma = MChroma.*groundTruthKNN( CSMChroma', round(size(CSMChroma', 2)*Kappa) )';        

            allScoresChroma(oti+1) = sqrt(prod(size(CSMChroma)))/swalignimp(double(full(MChroma)));
            dims = [size(MChroma); size(MMFCC)];
            dims = min(dims, [], 1);
            M = double(MChroma(1:dims(1), 1:dims(2)) + MMFCC(1:dims(1), 1:dims(2)) );
            M = double(M > 0);
            M = full(M);
            allScoresCombined(oti+1) = sqrt(prod(size(M)))/swalignimp(M);
        end
        %Find best scores over transpositions
        [ChromaScore, idx] = min(allScoresChroma);
        ScoresChroma(ii, jj) = ChromaScore;
        MinTransp(ii, jj) = idx;
        [Score, idx] = min(allScoresCombined);
        Scores(ii, jj) = Score;
        MinTranspCombined(ii, jj) = idx;
        fprintf(1, '.');
    end
end

save(sprintf('%s/%i_%i.mat', dirName, beatIdx1, beatIdx2), ...
    'ScoresChroma', 'ScoresMFCC', 'Scores', 'MinTransp', 'MinTranspCombined');
