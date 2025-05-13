clc;
clear;
close all;

% Step 1: Load and display the original image
originalImg = imread('C:\Users\ianbi\Desktop\MATLAB\Preprocessing\Truck\Truck2.jpg');

% Prepare a single figure window
figure('Name','License Plate Detection Steps','NumberTitle','off');
subplot(3,3,1), imshow(originalImg), title('Original Image');

% Step 2: Convert to grayscale
grayImg = rgb2gray(originalImg);
subplot(3,3,2), imshow(grayImg), title('Grayscale Image');

% Step 3: Enhance contrast
grayImg = imadjust(grayImg);
subplot(3,3,3), imshow(grayImg), title('Contrast Enhanced');

% Step 4: Edge detection using Canny
edges = edge(grayImg, 'Canny', [0.1 0.3]);
subplot(3,3,4), imshow(edges), title('Canny Edges');

% Step 5: Morphological closing
se = strel('rectangle', [3, 15]);
closedImg = imclose(edges, se);
subplot(3,3,5), imshow(closedImg), title('Morphological Closing');

% Step 6: Use regionprops to find candidate boxes
props = regionprops(closedImg, 'BoundingBox', 'Area', 'Extent');
candidateBoxes = [];

for k = 1:length(props)
    bbox = props(k).BoundingBox;
    area = props(k).Area;
    aspectRatio = bbox(3) / bbox(4);
    extent = props(k).Extent;
    
    if area > 200 && aspectRatio > 2 && aspectRatio < 6 && extent > 0.4
        candidateBoxes = [candidateBoxes; bbox];
    end
end

if isempty(candidateBoxes)
    disp('No candidate plate regions detected.');
    return;
end

% Step 7: Select largest candidate region
maxArea = 0;
plateBoundingBox = [];
for k = 1:size(candidateBoxes, 1)
    bbox = candidateBoxes(k,:);
    currentArea = bbox(3) * bbox(4);
    if currentArea > maxArea
        maxArea = currentArea;
        plateBoundingBox = bbox;
    end
end

% Step 8: Show detected box on original image
detectedImg = insertShape(originalImg, 'Rectangle', plateBoundingBox, 'Color', 'red', 'LineWidth', 2);
subplot(3,3,6), imshow(detectedImg), title('Detected Plate Box');

% Step 9: Crop the plate
plateImg = imcrop(grayImg, plateBoundingBox);
subplot(3,3,7), imshow(plateImg), title('Cropped Plate');

% Step 10: Enhance plate for OCR
% plateBW = imbinarize(plateImg, 'adaptive', 'Sensitivity', 0.45);
plateBW = imbinarize(plateImg)
plateBW = imcomplement(plateBW);
plateBW = medfilt2(plateBW, [2, 2]);  % Smoothing filter to reduce noise
subplot(3,3,8), imshow(plateBW), title('Enhanced for OCR');

% Step 10.1: Segment characters using regionprops
CC = bwconncomp(plateBW);
stats = regionprops(CC, 'BoundingBox', 'Area');
bboxes = cat(1, stats.BoundingBox);

% Sort bounding boxes by x (horizontal) position
[~, idx] = sort(bboxes(:,1));
sortedBoxes = bboxes(idx, :);

% Filter out boxes that are too small (noise)
filteredBoxes = [];
for i = 1:size(sortedBoxes,1)
    w = sortedBoxes(i,3);
    h = sortedBoxes(i,4);
    if w > 10 && h > 20 && w < 80 && h < 100  % reasonable width/height for chars
        filteredBoxes = [filteredBoxes; sortedBoxes(i,:)];
    end
end

firstCharBySegmentation = '';
if ~isempty(filteredBoxes)
    firstCharBox = filteredBoxes(1, :);  % First box from left
    firstCharImg = imcrop(plateBW, firstCharBox);
    firstCharImg = imresize(firstCharImg, [50 50]);  % Normalize size
    firstCharImg = imcomplement(firstCharImg);  % Black text on white background
    firstCharImg = imbinarize(firstCharImg);
    
    firstCharResult = ocr(firstCharImg, ...
        'CharacterSet', 'ABCDFJKMNPRTVWZ', 'TextLayout', 'Word');
    firstCharCleaned = upper(regexprep(firstCharResult.Text, '[^A-Z]', ''));
    
    if ~isempty(firstCharCleaned)
        firstCharBySegmentation = firstCharCleaned(1);
    end
end

% === ALTERNATIVE: Region-based detection for first char (left plate side) ===
firstCharByRegion = '';
[H, W] = size(plateBW);
leftQuarter = imcrop(plateBW, [1, 1, round(W/4), H]);
leftQuarter = imcomplement(leftQuarter);  % Invert image

% Check if 'leftQuarter' is binary. If not, apply imbinarize.
if ~islogical(leftQuarter)
    leftQuarter = imbinarize(leftQuarter);  % Binarize if not already binary
end

leftQuarter = imresize(leftQuarter, [50 50]);

regionOCR = ocr(leftQuarter, ...
    'CharacterSet', 'ABCDFJKMNPRTVWZ', 'TextLayout', 'Word');
cleanRegionText = upper(regexprep(regionOCR.Text, '[^A-Z]', ''));

if ~isempty(cleanRegionText)
    firstCharByRegion = cleanRegionText(1);
end


% Step 11: OCR for the full plate
results = ocr(plateBW, ...
    'CharacterSet', '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'TextLayout', 'Block');
recognizedText = upper(regexprep(results.Text, '[\s]', ''));
disp(['Recognized Plate Text: ', recognizedText]);

% Step 12: Detect Malaysian state
stateMap = containers.Map(...
    {'A','B','C','D','F','J','K','M','N','P','R','T','V','W','Z'}, ...
    {'Perak','Selangor','Pahang','Kelantan','Putrajaya','Johor','Kedah','Melaka','Negeri Sembilan','Penang','Perlis','Terengganu','Labuan','Kuala Lumpur','Military'});

% Prioritize by: Segmented > Region > Full Plate
if ~isempty(firstCharBySegmentation)
    firstChar = firstCharBySegmentation;
elseif ~isempty(firstCharByRegion)
    firstChar = firstCharByRegion;
elseif ~isempty(recognizedText)
    firstChar = recognizedText(1);
else
    firstChar = '';
end

if ~isempty(firstChar) && isKey(stateMap, firstChar)
    state = stateMap(firstChar);
else
    state = 'Unknown';
end

% Show debug info
disp(['First Char by Segmentation: ', firstCharBySegmentation]);
disp(['First Char by Region: ', firstCharByRegion]);
disp(['Final First Character Used: ', firstChar]);
disp(['Detected State: ', state]);

% Step 13: Display final result
subplot(3,3,9), imshow(plateBW), ...
    title({['OCR: ', recognizedText], ...
    ['SegChar: ', firstCharBySegmentation], ...
    ['RegionChar: ', firstCharByRegion], ...
    ['State: ', state]});
