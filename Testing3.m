clc;
clear;
close all;

% Step 1: Load and display the original image
originalImg = imread('C:\Users\ianbi\Desktop\MATLAB\Preprocessing\Bus\Bus3.jpg');

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
plateBW = medfilt2(plateBW, [2, 2]);
subplot(3,3,8), imshow(plateBW), title('Enhanced for OCR');

% Step 11: OCR
results = ocr(plateBW, 'CharacterSet', '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'TextLayout', 'Block');
recognizedText = regexprep(results.Text, '[\s]', '');

% Step 12: Display recognized text in command window and figure
disp(['Recognized Plate Text: ', recognizedText]);
subplot(3,3,9), imshow(plateBW), title(['OCR Result: ', recognizedText]);
