% Read the image
img = imread('C:\Users\ianbi\Desktop\MATLAB\Preprocessing\Car\Porsche.jpg');

% Step 1: Convert the image to grayscale
gray_img = rgb2gray(img);

% Step 2: Apply image thresholding (black and white)
bw_img = imbinarize(gray_img);

% Step 3: Edge Detection
edge_img = edge(bw_img, 'Canny');

% Step 4: Morphological dilation to enhance edges
se = strel('rectangle', [5,5]); % Create a structuring element (you can change size)
dilated_img = imdilate(edge_img, se);

% Step 5: Find the license plate region
% Using region properties to detect the plate based on its size
stats = regionprops(dilated_img, 'BoundingBox', 'Area');
% Filter regions based on area (you can tweak the area threshold)
plate_regions = stats([stats.Area] > 1000); % You can adjust threshold for plate size

% Step 6: Extract the license plate region from the image
if ~isempty(plate_regions)
    for k = 1:length(plate_regions)
        % Extract bounding box of the license plate
        bbox = plate_regions(k).BoundingBox;
        plate = imcrop(gray_img, bbox); % Crop the license plate area
        
        % Step 7: Apply thresholding to the cropped region (to isolate characters)
        plate_bw = imbinarize(plate);
        
        % Step 8: Perform morphological operations (like dilation) to separate characters
        plate_dilated = imdilate(plate_bw, se);
        
        % Step 9: Find individual characters in the plate
        char_stats = regionprops(plate_dilated, 'BoundingBox');
        
        % Step 10: Extract each character
        for i = 1:length(char_stats)
            char_bbox = char_stats(i).BoundingBox;
            char_img = imcrop(plate_dilated, char_bbox); % Crop each character
            imshow(char_img); % Display character
            pause(0.5); % Wait a bit to show each character (optional)
        end
        
        % You can integrate OCR here if you need to recognize the text
        ocr_result = ocr(plate); % OCR to detect the text on the plate
        disp('Detected Text:');
        disp(ocr_result.Text);
        
        % Here, you could match the detected plate number with the format
        % for the state identification (this will depend on your data).
    end
else
    disp('License plate not found.');
end
