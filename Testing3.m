clc;
clear;
close all;

% Step 1: Load and display the original image
originalImg = imread('C:\Users\ianbi\Desktop\MATLAB\Preprocessing\Car\Hilux.jpg');
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

% (Optional) Uncomment below to fill holes if necessary
% filledImg = imfill(closedImg, 'holes');
% figure, imshow(filledImg), title('Hole Filled Image');

% Step 6: Use regionprops to extract candidate regions
props = regionprops(closedImg, 'BoundingBox', 'Area', 'Extent');
candidateBoxes = [];

% Filter based on typical number plate properties (area, aspect ratio, and extent)
for k = 1:length(props)
    bbox = props(k).BoundingBox;
    area = props(k).Area;
    aspectRatio = bbox(3) / bbox(4); % width/height
    extent = props(k).Extent;         % ratio of region area to bbox area
    
    % Adjust thresholds for your specific images:
    if area > 200 && aspectRatio > 2 && aspectRatio < 6 && extent > 0.4
        candidateBoxes = [candidateBoxes; bbox];
    end
end

if isempty(candidateBoxes)
    disp('No candidate plate regions detected.');
    return;
end

% Step 7: Select the candidate region with the largest area
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

% Step 8: Crop the candidate region from the grayscale image
plateImg = imcrop(grayImg, plateBoundingBox);
figure, imshow(plateImg), title('Cropped Plate Region');

% Step 9: Enhance the cropped plate image for OCR
plateBW = imbinarize(plateImg, 'adaptive', 'Sensitivity', 0.45);
plateBW = imcomplement(plateBW);  % invert if necessary so text is dark on a light background
plateBW = medfilt2(plateBW, [2, 2]); % smooth out noise
figure, imshow(plateBW), title('Enhanced Plate for OCR');

% Step 10: Apply OCR to extract text
results = ocr(plateBW, 'CharacterSet', '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'TextLayout', 'Block');

% Remove any whitespace from the OCR result
recognizedText = regexprep(results.Text, '[\s]', '');
disp(['Recognized Plate Text: ', recognizedText]);
