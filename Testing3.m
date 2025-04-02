clc;
clear;
close all;

% Step 1: Load and display the original image
originalImg = imread('C:\Users\ianbi\Desktop\MATLAB\Preprocessing\GG\IMG-20250402-WA0146.jpg');
figure, imshow(originalImg), title('Original Image');

% Step 2: Convert to grayscale
grayImg = rgb2gray(originalImg);
figure, imshow(grayImg), title('Grayscale Image');

% Step 3: Enhance contrast to improve edge detection
grayImg = imadjust(grayImg);
figure, imshow(grayImg), title('Contrast Enhanced Image');

% Step 4: Edge detection using Canny (adjust thresholds if needed)
edges = edge(grayImg, 'Canny', [0.1 0.3]);
figure, imshow(edges), title('Canny Edge Detection');

% Step 5: Morphological closing to connect nearby edge segments
se = strel('rectangle', [3, 15]);  % Adjust size as needed
closedImg = imclose(edges, se);
figure, imshow(closedImg), title('Morphologically Closed Image');

% Step 6: Use regionprops to extract candidate regions
image_area = numel(grayImg);
props = regionprops(closedImg, 'BoundingBox', 'Area', 'Extent');
candidateBoxes = [];
singleRowCandidates = [];
doubleRowCandidates = [];

% Filter based on license plate properties with different format considerations
for k = 1:length(props)
    bbox = props(k).BoundingBox;
    area = props(k).Area;
    aspectRatio = bbox(3) / bbox(4); % width/height
    extent = props(k).Extent;         % ratio of region area to bbox area
    
    % Add to overall candidates
    if area > 0.0005*image_area && extent > 0.4
        candidateBoxes = [candidateBoxes; bbox];
        
        % Check for single-row plate (wider than tall)
        if aspectRatio > 2 && aspectRatio < 6
            singleRowCandidates = [singleRowCandidates; bbox];
            % Check for double-row plate (more square-like)
        elseif aspectRatio > 0.7 && aspectRatio < 2
            doubleRowCandidates = [doubleRowCandidates; bbox];
        end
    end
end

if isempty(candidateBoxes)
    disp('No candidate plate regions detected.');
    return;
end

% Determine whether to process as single or double row format
if ~isempty(singleRowCandidates)
    disp('Detected potential single-row license plates');
    formatType = 'single';
    formatCandidates = singleRowCandidates;
elseif ~isempty(doubleRowCandidates)
    disp('Detected potential double-row license plates');
    formatType = 'double';
    formatCandidates = doubleRowCandidates;
else
    disp('No valid license plate format detected.');
    return;
end

% Step 7: Select the candidate region with the largest area
maxArea = 0;
plateBoundingBox = [];
for k = 1:size(formatCandidates, 1)
    bbox = formatCandidates(k,:);
    currentArea = bbox(3) * bbox(4);
    if currentArea > maxArea
        maxArea = currentArea;
        plateBoundingBox = bbox;
    end
end

% Visualize the detected candidate region on the original image
figure, imshow(originalImg), title(['Detected ' formatType '-row Plate Candidate']);
rectangle('Position', plateBoundingBox, 'EdgeColor', 'r', 'LineWidth', 2);

% Step 8: Crop the candidate region from the grayscale image
plateImg = imcrop(grayImg, plateBoundingBox);
figure, imshow(plateImg), title('Cropped Plate Region');

% Step 9: Enhance the cropped plate image for OCR
plateBW = imbinarize(plateImg, 'adaptive', 'Sensitivity', 0.45);
plateBW = imcomplement(plateBW);  % invert if necessary so text is dark on a light background
plateBW = medfilt2(plateBW, [2, 2]); % smooth out noise
plateBW = bwareaopen(plateBW, 20); % removes small noise

% Resize for better OCR
plateBW = imresize(plateBW, 2, 'bilinear'); % enlarge by a factor of 2
figure, imshow(plateBW), title('Enhanced Plate for OCR');

% Step 10: Apply OCR based on the detected plate format
if strcmp(formatType, 'single')
    % Single row layout - process as a block
    results = ocr(plateBW, 'CharacterSet', '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'TextLayout', 'Block');
    
    % Remove any whitespace from the OCR result
    recognizedText = regexprep(results.Text, '[\s]', '');
    disp(['Recognized Single-Row Plate Text: ', recognizedText]);
else
    % Double row layout - try to detect text in upper and lower regions separately
    [height, width] = size(plateBW);
    
    % Split the plate into upper and lower halves
    upperHalf = plateBW(1:round(height/2), :);
    lowerHalf = plateBW(round(height/2)+1:end, :);
    
    % Process upper half (typically letters)
    resultsUpper = ocr(upperHalf, 'CharacterSet', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'TextLayout', 'Block');
    
    % Process lower half (typically numbers)
    resultsLower = ocr(lowerHalf, 'CharacterSet', '0123456789', 'TextLayout', 'Block');
    
    % Clean up the results
    upperText = regexprep(resultsUpper.Text, '[\s]', '');
    lowerText = regexprep(resultsLower.Text, '[\s]', '');
    
    % Combine the results
    recognizedText = [upperText lowerText];
    
    % Display the individual results and combined
    disp(['Recognized Upper Row: ', upperText]);
    disp(['Recognized Lower Row: ', lowerText]);
    disp(['Complete Plate: ', recognizedText]);
    
    % Display the split processing
    figure;
    subplot(2,1,1);
    imshow(upperHalf);
    title(['Upper Row: ', upperText]);
    
    subplot(2,1,2);
    imshow(lowerHalf);
    title(['Lower Row: ', lowerText]);
end

% Display the final result on the original image
figure;
imgWithText = insertText(originalImg, [plateBoundingBox(1), plateBoundingBox(2)-30], ...
    ['Plate: ', recognizedText], 'FontSize', 18, 'BoxColor', 'yellow', 'TextColor', 'black');
imshow(imgWithText);
title('License Plate Detection Result');

% Enhanced validation for Malaysian formats
if ~isempty(recognizedText)
    % Check if the format looks like a valid Malaysian plate
    if regexp(recognizedText, '^[A-Z]{1,3}\d{1,4}[A-Z]?$')
        disp('Format validation: Valid Malaysian license plate format detected!');
    else
        disp('Format validation: Text does not match typical Malaysian plate format. Verification needed.');
    end
end