clc;
clear;
close all;

% Step 1: Load and display the original image
originalImg = imread('C:\Users\ianbi\Desktop\MATLAB\Preprocessing\Car\Porsche.jpg');

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
plateBW = imbinarize(plateImg, 'adaptive', 'Sensitivity', 0.45);
plateBW = imcomplement(plateBW);
plateBW = medfilt2(plateBW, [2, 2]);  % Smoothing filter to reduce noise
subplot(3,3,8), imshow(plateBW), title('Enhanced for OCR');

% Step 10.1: Segment first character carefully
CC = bwconncomp(plateBW);
stats = regionprops(CC, 'BoundingBox', 'Area');
bboxes = cat(1, stats.BoundingBox);

% Sort bounding boxes by horizontal position (left to right)
[~, idx] = sort(bboxes(:,1));
sortedBoxes = bboxes(idx, :);

% Filter out small bounding boxes (noise)
filteredBoxes = [];
for i = 1:size(sortedBoxes,1)
    if sortedBoxes(i,3) > 10 && sortedBoxes(i,4) > 20  % Min width and height
        filteredBoxes = [filteredBoxes; sortedBoxes(i,:)];
    end
end

% Only process the first character
firstCharBySegmentation = '';
if ~isempty(filteredBoxes)
    firstCharBox = filteredBoxes(1, :);  % The first box is the first character
    firstCharImg = imcrop(plateBW, firstCharBox);
    firstCharImg = imresize(firstCharImg, [50 50]);  % Resize for better OCR accuracy
    firstCharImg = imcomplement(firstCharImg);  % Invert the image to black text on white background
    
    % OCR to detect the first character
    charResult = ocr(firstCharImg, 'CharacterSet', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', 'TextLayout', 'Word');
    firstCharBySegmentation = upper(regexprep(charResult.Text, '[\s]', ''));
    disp(['First Character by Segmentation: ', firstCharBySegmentation]);
else
    disp('First character could not be segmented.');
end

% Step 11: OCR for the full plate
results = ocr(plateBW, 'CharacterSet', '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'TextLayout', 'Block');
recognizedText = upper(regexprep(results.Text, '[\s]', ''));
disp(['Recognized Plate Text: ', recognizedText]);

% Step 12: Detect Malaysian state based on first character
stateMap = containers.Map(...
    {'A','B','C','D','F','J','K','M','N','P','R','T','V','W','Z'}, ...
    {'Perak','Selangor','Pahang','Kelantan','Putrajaya','Johor','Kedah','Melaka','Negeri Sembilan','Penang','Perlis','Terengganu','Labuan','Kuala Lumpur','Military'});

if ~isempty(recognizedText)
    if ~isempty(firstCharBySegmentation) && firstCharBySegmentation(1) == recognizedText(1)
        firstChar = firstCharBySegmentation(1);  % Use segmented character
    else
        firstChar = recognizedText(1);  % Fallback to OCR-recognized first character
    end
elseif ~isempty(firstCharBySegmentation)
    firstChar = firstCharBySegmentation(1);
else
    firstChar = '';
end

% Detect state from the first character
if ~isempty(firstChar) && isKey(stateMap, firstChar)
    state = stateMap(firstChar);
    disp(['Detected State: ', state]);
else
    state = 'Unknown';
    disp('State could not be identified from plate prefix.');
end

% Step 13: Display final result with OCR output and detected state
subplot(3,3,9), imshow(plateBW), ...
    title({['OCR: ', recognizedText], ['SegFirstChar: ', firstCharBySegmentation], ['State: ', state]});
