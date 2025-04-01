clc;
clear;
close all;

% Step 1: Load and display the original image
originalImg = imread('C:\Users\ianbi\Desktop\MATLAB\Preprocessing\Tank\Tank5.jpg');
figure, imshow(originalImg), title('Original Image');

% Step 2: Convert to grayscale
grayImg = rgb2gray(originalImg);
figure, imshow(grayImg), title('Grayscale Image');

% Step 3: Enhance contrast using adaptive histogram equalization
grayImg = adapthisteq(grayImg);
figure, imshow(grayImg), title('Contrast Enhanced Image');

% Step 4: Noise reduction using Gaussian filter
grayImg = imgaussfilt(grayImg, 2);
figure, imshow(grayImg), title('Noise Reduced Image');

% Step 5: Adaptive thresholding
bwImg = imbinarize(grayImg, 'adaptive', 'Sensitivity', 0.4);
figure, imshow(bwImg), title('Adaptive Thresholding');

% Step 6: Edge detection using Canny with adjusted thresholds
edges = edge(bwImg, 'Canny', [0.05 0.2]);
figure, imshow(edges), title('Canny Edge Detection');

% Step 7: Morphological operations with fine-tuned structuring elements
se1 = strel('rectangle', [2, 10]); % Smaller structuring element
se2 = strel('rectangle', [3, 3]);  % Smaller structuring element
dilatedImg = imdilate(edges, se1);
closedImg = imerode(dilatedImg, se2);
figure, imshow(closedImg), title('Morphologically Processed Image');

% Step 8: Use regionprops to extract candidate regions
props = regionprops(closedImg, 'BoundingBox', 'Area', 'Extent', 'Solidity', 'Eccentricity');
candidateBoxes = [];

% Filter based on typical number plate properties
for k = 1:length(props)
    bbox = props(k).BoundingBox;
    area = props(k).Area;
    aspectRatio = bbox(3) / bbox(4); % width/height
    extent = props(k).Extent;         % ratio of region area to bbox area
    solidity = props(k).Solidity;
    eccentricity = props(k).Eccentricity;
    
    % Adjust thresholds for your specific images:
    if area > 200 && aspectRatio > 2 && aspectRatio < 6 && extent > 0.4 && solidity > 0.5 && eccentricity < 0.9
        candidateBoxes = [candidateBoxes; bbox];
    end
end

if isempty(candidateBoxes)
    disp('No candidate plate regions detected.');
    return;
end

% Step 9: Select the candidate region with the largest area
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

% Visualize the detected candidate region on the original image
figure, imshow(originalImg), title('Detected Plate Candidate');
rectangle('Position', plateBoundingBox, 'EdgeColor', 'r', 'LineWidth', 2);

% Step 10: Crop the candidate region from the grayscale image
plateImg = imcrop(grayImg, plateBoundingBox);
figure, imshow(plateImg), title('Cropped Plate Region');

% Step 11: Enhance the cropped plate image for OCR
plateBW = imbinarize(plateImg, 'adaptive', 'Sensitivity', 0.45);
plateBW = imcomplement(plateBW);  % invert if necessary so text is dark on a light background
plateBW = medfilt2(plateBW, [2, 2]); % smooth out noise
plateBW = imdilate(plateBW, strel('disk', 1)); % dilate to improve character separation
figure, imshow(plateBW), title('Enhanced Plate for OCR');

% Step 12: Apply OCR to extract text
results = ocr(plateBW, 'CharacterSet', '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'TextLayout', 'Block');

% Remove any whitespace from the OCR result
recognizedText = regexprep(results.Text, '[\s]', '');
disp(['Recognized Plate Text: ', recognizedText]);