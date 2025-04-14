function detectMalaysianLicensePlate()
% Enhanced Malaysian License Plate Detection with format selection
% Handles both single-row and double-row license plates with improved detection

clc;
clear;
close all;

% Ask user to select an image file
[filename, filepath] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif', 'Image Files'}, 'Select an image with a license plate');

% Check if user canceled the file selection
if isequal(filename, 0) || isequal(filepath, 0)
    disp('File selection canceled. Exiting function.');
    return;
end

% Construct full file path
imagePath = fullfile(filepath, filename);

% Ask user about plate format preference
formatChoice = menu('Select license plate format:', 'Auto-detect', 'Single-row', 'Double-row');

if formatChoice == 0
    disp('Operation canceled. Exiting function.');
    return;
elseif formatChoice == 1
    plateFormat = 'auto';
elseif formatChoice == 2
    plateFormat = 'single';
else
    plateFormat = 'double';
end

% Load and display the original image
originalImg = imread(imagePath);
figure, imshow(originalImg), title('Original Image');

% Convert to grayscale if needed
if size(originalImg, 3) == 3
    grayImg = rgb2gray(originalImg);
else
    grayImg = originalImg;
end
figure, imshow(grayImg), title('Grayscale Image');

% Enhance contrast to improve edge detection
grayImg = imadjust(grayImg);
figure, imshow(grayImg), title('Contrast Enhanced Image');

% Apply bilateral filtering to reduce noise while preserving edges
grayImg = imbilatfilt(grayImg, 'DegreeOfSmoothing', 2, 'SpatialSigma', 1);
figure, imshow(grayImg), title('Noise Reduced Image');

% Edge detection using Canny
edges = edge(grayImg, 'Canny', [0.1 0.3]);
figure, imshow(edges), title('Canny Edge Detection');

% Different morphological operations for single and double row plates
% Horizontal connections (for both formats)
seHorz = strel('rectangle', [3, 15]);
closedImgHorz = imclose(edges, seHorz);

% Vertical connections (especially important for double-row plates)
seVert = strel('rectangle', [15, 3]);
closedImgVert = imclose(edges, seVert);

% Combine both (weighted towards horizontal for single-row, equal for double-row)
if strcmpi(plateFormat, 'single')
    closedImg = closedImgHorz;
elseif strcmpi(plateFormat, 'double')
    closedImg = closedImgHorz | closedImgVert;
else % auto
    closedImg = closedImgHorz | closedImgVert;
end

figure, imshow(closedImg), title('Morphologically Processed Image');

% Fill holes to create solid regions
filledImg = imfill(closedImg, 'holes');
figure, imshow(filledImg), title('Filled Image');

% Use regionprops to extract candidate regions
image_area = numel(grayImg);
props = regionprops(filledImg, 'BoundingBox', 'Area', 'Extent', 'Solidity', 'Orientation');

% Initialize candidate arrays
singleRowCandidates = [];
doubleRowCandidates = [];

% Filter based on plate properties
for k = 1:length(props)
    bbox = props(k).BoundingBox;
    area = props(k).Area;
    aspectRatio = bbox(3) / bbox(4); % width/height
    extent = props(k).Extent;         % ratio of region area to bbox area
    solidity = props(k).Solidity;     % ratio of area to convex hull area
    orientation = props(k).Orientation; % orientation in degrees
    
    % Minimum requirements for any plate
    if area > 0.0005*image_area && area < 0.05*image_area && ...
            extent > 0.4 && solidity > 0.5
        
        % Single-row plate specific criteria (wider rectangle)
        if aspectRatio > 2 && aspectRatio < 7 && abs(orientation) < 30
            singleRowCandidates = [singleRowCandidates; bbox];
        end
        
        % Enhanced Double-row plate specific criteria (more square-like)
        if aspectRatio > 0.8 && aspectRatio < 1.8 && abs(orientation) < 45 && ...
                (extent > 0.5 || solidity > 0.6)
            doubleRowCandidates = [doubleRowCandidates; bbox];
        end
    end
end

% Determine plate format to process
if strcmpi(plateFormat, 'single')
    formatCandidates = singleRowCandidates;
    formatType = 'single';
elseif strcmpi(plateFormat, 'double')
    formatCandidates = doubleRowCandidates;
    formatType = 'double';
else % Auto-detect
    % Choose based on available candidates
    if ~isempty(singleRowCandidates) && isempty(doubleRowCandidates)
        formatCandidates = singleRowCandidates;
        formatType = 'single';
    elseif isempty(singleRowCandidates) && ~isempty(doubleRowCandidates)
        formatCandidates = doubleRowCandidates;
        formatType = 'double';
    elseif ~isempty(singleRowCandidates) && ~isempty(doubleRowCandidates)
        % If both formats detected, select the one with the largest area candidate
        maxSingleArea = 0;
        for i = 1:size(singleRowCandidates, 1)
            bbox = singleRowCandidates(i,:);
            area = bbox(3) * bbox(4);
            if area > maxSingleArea
                maxSingleArea = area;
            end
        end
        
        maxDoubleArea = 0;
        for i = 1:size(doubleRowCandidates, 1)
            bbox = doubleRowCandidates(i,:);
            area = bbox(3) * bbox(4);
            if area > maxDoubleArea
                maxDoubleArea = area;
            end
        end
        
        if maxSingleArea > maxDoubleArea
            formatCandidates = singleRowCandidates;
            formatType = 'single';
        else
            formatCandidates = doubleRowCandidates;
            formatType = 'double';
        end
    else
        % No candidates of either format detected
        disp('No valid license plate regions detected.');
        return;
    end
end

% Validate we have candidates to process
if isempty(formatCandidates)
    disp(['No ', formatType, '-row plate candidates detected.']);
    return;
else
    disp(['Processing as ', formatType, '-row plate format.']);
end

% Select the candidate with the largest area
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

% Visualize the detected plate region
figure, imshow(originalImg), title(['Detected ', formatType, '-row Plate']);
rectangle('Position', plateBoundingBox, 'EdgeColor', 'r', 'LineWidth', 2);

% Crop the plate region
plateImg = imcrop(grayImg, plateBoundingBox);
figure, imshow(plateImg), title('Cropped Plate Region');

% Enhanced preprocessing for OCR
% Increase contrast for better character separation
plateImg = imadjust(plateImg);

% Adaptive binarization
plateBW = imbinarize(plateImg, 'adaptive', 'Sensitivity', 0.45);

% Determine if we need to invert (most Malaysian plates have dark background)
borderPixels = [plateBW(1,:), plateBW(end,:), plateBW(:,1)', plateBW(:,end)'];
if mean(borderPixels) < 0.5
    % Dark background, light text - invert
    plateBW = ~plateBW;
end

% Noise reduction
plateBW = medfilt2(plateBW, [2, 2]);
plateBW = bwareaopen(plateBW, 20); % Remove small noise

% Enlarge image for better OCR
plateBW = imresize(plateBW, 2, 'bilinear');
figure, imshow(plateBW), title('Enhanced Plate for OCR');

% Process based on plate format
if strcmpi(formatType, 'single')
    % Process as a single text block
    results = ocr(plateBW, 'CharacterSet', '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', ...
        'TextLayout', 'Block');
    
    % Clean up the results
    recognizedText = regexprep(results.Text, '[^0-9A-Z]', '');
    
    % Display results
    disp(['Recognized Text: ', recognizedText]);
    
    % Visualize character detection
    if ~isempty(results.Words)
        figure;
        showBoxes = insertObjectAnnotation(plateImg, 'rectangle', ...
            results.Words(:).BoundingBox, results.Words(:).Text, 'LineWidth', 2);
        imshow(showBoxes);
        title('Character Recognition');
    end
else
    % Enhanced double-row processing
    [upperHalf, lowerHalf] = separatePlateRows(plateBW);
    
    % Process upper row (typically letters)
    resultsUpper = ocr(upperHalf, 'CharacterSet', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', ...
        'TextLayout', 'Word', 'Language', 'English', 'TextEncoding', 'UTF-8');
    
    % Process lower row (typically numbers)
    resultsLower = ocr(lowerHalf, 'CharacterSet', '0123456789', ...
        'TextLayout', 'Word', 'Language', 'English', 'TextEncoding', 'UTF-8');
    
    % Clean up results
    upperText = regexprep(resultsUpper.Text, '[^A-Z]', '');
    lowerText = regexprep(resultsLower.Text, '[^0-9]', '');
    
    % Display individual row results
    disp(['Upper Row (Letters): ', upperText]);
    disp(['Lower Row (Numbers): ', lowerText]);
    
    % Combine the results
    recognizedText = [upperText lowerText];
    disp(['Combined Plate: ', recognizedText]);
    
    % Display the split processing
    figure;
    subplot(2,1,1);
    imshow(upperHalf);
    title(['Upper Row: ', upperText]);
    
    subplot(2,1,2);
    imshow(lowerHalf);
    title(['Lower Row: ', lowerText]);
end

% Validate against Malaysian plate format
if ~isempty(recognizedText)
    % Typical formats:
    % Single row: ABC 1234 or ABC 123
    % Double row: ABC over 1234
    
    if regexp(recognizedText, '^[A-Z]{2,3}\d{3,4}[A-Z]?$')
        disp('Format validation: Valid Malaysian license plate format detected!');
    else
        disp('Format validation: Text may not match typical Malaysian plate format. Verification needed.');
    end
end

% Display final result on original image
figure;
imgWithText = insertText(originalImg, [plateBoundingBox(1), plateBoundingBox(2)-30], ...
    ['Plate: ', recognizedText], 'FontSize', 18, 'BoxColor', 'yellow', 'TextColor', 'black');
imshow(imgWithText);
title('License Plate Recognition Result');

% ------------------------------------------------------------------------
% Helper function for separating double-row plates
    function [upperHalf, lowerHalf] = separatePlateRows(bwImg)
        % Calculate horizontal projection with smoothing
        horizontalProj = sum(bwImg, 2);
        horizontalProj = horizontalProj / max(horizontalProj);
        horizontalProj = smoothdata(horizontalProj, 'gaussian', 7);
        
        % Find potential split points (minima in projection)
        [minVals, minLocs] = findpeaks(-horizontalProj, 'MinPeakHeight', -0.5);
        
        if ~isempty(minLocs)
            % Choose the most central minimum point
            [~, idx] = min(abs(minLocs - size(bwImg,1)/2));
            rowSeparationLine = minLocs(idx);
            
            % Ensure we have reasonable sized rows
            minRowHeight = 0.25 * size(bwImg,1);
            if rowSeparationLine > minRowHeight && ...
                    (size(bwImg,1) - rowSeparationLine > minRowHeight)
                upperHalf = bwImg(1:rowSeparationLine, :);
                lowerHalf = bwImg(rowSeparationLine+1:end, :);
                return;
            end
        end
        
        % Fallback: vertical split if horizontal fails
        verticalProj = sum(bwImg, 1);
        verticalProj = verticalProj / max(verticalProj);
        verticalProj = smoothdata(verticalProj, 'gaussian', 7);
        
        [~, splitCol] = min(abs(verticalProj - 0.5));
        upperHalf = bwImg(:, 1:splitCol);
        lowerHalf = bwImg(:, splitCol+1:end);
    end
% ------------------------------------------------------------------------

end