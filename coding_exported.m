classdef coding_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                      matlab.ui.Figure
        CreatedbyWongWeiFongTP065467IanGanJianHaoTP064373Label  matlab.ui.control.Label
        RecognisedCarPlateEditField   matlab.ui.control.EditField
        VehicleStateCharacteisticsEditField  matlab.ui.control.EditField
        VehicleStateCharacteisticsEditFieldLabel  matlab.ui.control.Label
        FirstCharacterEditField       matlab.ui.control.EditField
        FirstCharacterEditFieldLabel  matlab.ui.control.Label
        RecognisedCarPlateEditFieldLabel  matlab.ui.control.Label
        LicensePlateRecognitionLPRandStateIdentificationSystemSISLabel  matlab.ui.control.Label
        CategoryButtonGroup           matlab.ui.container.ButtonGroup
        TaxiButton                    matlab.ui.control.ToggleButton
        BoatButton                    matlab.ui.control.ToggleButton
        BusButton                     matlab.ui.control.ToggleButton
        CarButton                     matlab.ui.control.ToggleButton
        LorryButton                   matlab.ui.control.ToggleButton
        SampleDropDown                matlab.ui.control.DropDown
        AnalyseButton                 matlab.ui.control.Button
        SampleDropDownLabel           matlab.ui.control.Label
        Image                         matlab.ui.control.Image
    end

    
    properties (Access = private)
        CurrentCategory % Description
    end
    
    methods (Access = private)
        
        function analyzeImage(app, imagePath)
            clc;
            close all;

            % Step 1: Load and display the original image
            originalImg = imread(imagePath);
            
            % Prepare a single figure window
            figure('Name','License Plate Detection Steps','NumberTitle','off');
            subplot(3,3,1), imshow(originalImg), title('Original Image');
            %figure, imshow(originalImg), title('Original Image');
            
            % Step 2: Convert to grayscale
            grayImg = rgb2gray(originalImg);
            subplot(3,3,2), imshow(grayImg), title('Grayscale Image');
            %figure, imshow(grayImg), title('Grayscale Image');
            
            % Step 3: Enhance contrast
            grayImg = imadjust(grayImg);
            subplot(3,3,3), imshow(grayImg), title('Contrast Enhanced');
            %figure, imshow(grayImg), title('Contrast Enhanced');
            
            % Step 4: Edge detection using Canny
            edges = edge(grayImg, 'Canny', [0.1 0.3]);
            subplot(3,3,4), imshow(edges), title('Canny Edges');
            %figure, imshow(edges), title('Canny Edges');
            
            % Step 5: Morphological closing
            se = strel('rectangle', [3, 15]);
            closedImg = imclose(edges, se);
            subplot(3,3,5), imshow(closedImg), title('Morphological Closing');
            %figure, imshow(closedImg), title('Morphological Closing');

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

            % Step 8: Crop the plate
            plateImg = imcrop(grayImg, plateBoundingBox);
            subplot(3,3,6), imshow(plateImg), title('Cropped Plate');
            %figure, imshow(plateImg), title('Cropped Plate');
            
            % Step 9: Enhance the plate for OCR (FULL PLATE)
            avgLum = mean(plateImg(:));
            if avgLum > 128
                pol = 'dark';   % white background, dark text
            else
                pol = 'bright'; % dark background, bright text
            end
            
            % Mild binarization for full plate OCR
            plateBW_Full = imbinarize(plateImg, 'adaptive', 'Sensitivity', 0.4, 'ForegroundPolarity', pol);
            plateBW_Full = bwareaopen(plateBW_Full, 30);
            plateBW_Full = medfilt2(plateBW_Full, [2, 2]);
            
            % Display intermediate step for debugging
            subplot(3,3,7), imshow(plateBW_Full), title('Enhanced for Full Plate OCR');
            %figure, imshow(plateBW_Full), title('Enhanced for Full Plate OCR');
            
            % Step 10: OCR for the full plate
            resultsFull = ocr(plateBW_Full, 'CharacterSet', '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'TextLayout', 'Block');
            recognizedText = upper(regexprep(resultsFull.Text, '[\s]', ''));
            
            disp(['Recognized Full Plate Text: ', recognizedText]);
            
            % Step 11: Isolate first character region from original cropped image
            firstCharWidth = round(size(plateImg,2) * 0.2);  
            firstCharBox = [1, 1, firstCharWidth, size(plateImg, 1)];
            firstCharImg = imcrop(plateImg, [1, 1, firstCharWidth, size(plateImg,1)]);
            
            % Stronger enhancement for first character OCR
            avgLumChar = mean(firstCharImg(:));
            if avgLumChar > 128
                polChar = 'dark';
            else
                polChar = 'bright';
            end
            
            firstCharBW = imbinarize(firstCharImg, 'adaptive', 'Sensitivity', 0.5, 'ForegroundPolarity', polChar);
            firstCharBW = imfill(firstCharBW, 'holes');
            firstCharBW = bwareaopen(firstCharBW, 20);
            firstCharBW = medfilt2(firstCharBW, [2,2]);
            
            % Convert binary image to uint8 before sharpening
            firstCharBW_uint8 = uint8(firstCharBW) * 255;
            
            % Sharpening step
            firstCharBW_sharp = imsharpen(firstCharBW_uint8, 'Radius', 1, 'Amount', 2);
            
            % Optional reconversion to binary for OCR
            firstCharBW_final = imbinarize(firstCharBW_sharp);
            
            % Display enhanced first character region for debugging
            subplot(3,3,8), imshow(firstCharBW_final), title('Enhanced for First Character OCR');
            %figure, imshow(firstCharBW_final), title('Enhanced for First Character OCR');
            
            % Step 12: OCR for first character only
            resultsChar = ocr(firstCharBW_final, ...
                'CharacterSet', 'ABCDFHJKLMNPQRSTUVWZ', 'TextLayout', 'Word');
            
            firstCharCleaned = upper(regexprep(resultsChar.Text, '[^A-Z]', ''));
            if ~isempty(firstCharCleaned)
                firstCharDetected = firstCharCleaned(1);
            elseif ~isempty(recognizedText)
                 firstCharDetected = recognizedText(1);
            else
                firstCharDetected = 'NONE';
            end
            
            disp(['Recognized First Character: ', firstCharDetected]);

            
            % Step 13: State identification using the first character
            stateMap = containers.Map(...
                {'A','B','C','D','F','H','J','K','L','M','N','P','Q','R','S','T','U','V','W','Z'}, ...
                {'Perak','Selangor','Pahang','Kelantan','Putrajaya','Taxi','Johor','Kedah','Labuan','Melaka','Negeri Sembilan','Penang','Sarawak','Perlis','Sabah','Terengganu','iM4U Sentral','Kuala Lumpur','Kuala Lumpur','Military'});
            
            if isKey(stateMap, firstCharDetected)
                detectedState = stateMap(firstCharDetected);
            else
                detectedState = 'Unknown';
            end
            
            disp(['Detected State: ', detectedState]);
            
            % Step 14: Update the GUI
            app.RecognisedCarPlateEditField.Value = recognizedText;
            app.FirstCharacterEditField.Value = firstCharDetected;
            app.VehicleStateCharacteisticsEditField.Value = detectedState;


            % === Insert red plate + green first character box ===
            shapes = plateBoundingBox;
            colors = {'red'};
            if ~isempty(firstCharBox)
                % Convert firstCharBox to original image coords
                adjustedFirstCharBox = firstCharBox;
                adjustedFirstCharBox(1) = adjustedFirstCharBox(1) + plateBoundingBox(1);
                adjustedFirstCharBox(2) = adjustedFirstCharBox(2) + plateBoundingBox(2);
                shapes = [shapes; adjustedFirstCharBox];
                colors = [colors, {'green'}];
            end
            detectedImg = insertShape(originalImg, 'rectangle', shapes, 'Color', colors, 'LineWidth', 2);
            %subplot(3,3,9), imshow(detectedImg), title('Detected Plate Box');
            %figure, imshow(detectedImg), title('Detected Plate Box');

            app.RecognisedCarPlateEditField.Value = recognizedText;
            app.FirstCharacterEditField.Value = firstCharDetected;
            app.VehicleStateCharacteisticsEditField.Value = detectedState;
            
            % Step 13: Display final result
            subplot(3,3,9), imshow(firstCharBW_final), ...
                title({['Car Plate: ', recognizedText], ...
                ['First Character: ', firstCharDetected], ...
                ['State: ', detectedState]});
            figure, imshow(detectedImg), title('Detected Plate Box');
                    end
                end
            
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            app.Image.ScaleMethod = 'fit';
            app.CurrentCategory = app.CategoryButtonGroup.SelectedObject.Text;
            CategoryButtonGroupSelectionChanged(app, []);  % Simulate selection to load images
        end

        % Callback function: AnalyseButton, FirstCharacterEditField, 
        % ...and 2 other components
        function AnalyzeButtonPushed(app, event)
            selectedFile = app.SampleDropDown.Value;
            selectedCategory = app.CurrentCategory;
        
            %baseImagePath = 'C:\IPPR\matlab\Preprocessing';  % Adjust as needed
            baseImagePath = fullfile(fileparts(mfilename('fullpath')), 'Preprocessing');
            imagePath = fullfile(baseImagePath, selectedCategory, selectedFile);
        
            if isfile(imagePath)
                analyzeImage(app, imagePath);
            else
                uialert(app.UIFigure, 'Selected image not found.', 'Error');
            end
        end

        % Value changed function: SampleDropDown
        function SampleDropDownValueChanged(app, event)
            selectedFile = app.SampleDropDown.Value;
            selectedCategory = app.CurrentCategory;
        
            %baseImagePath = 'C:\IPPR\matlab\Preprocessing';  % Match your folder path
            baseImagePath = fullfile(fileparts(mfilename('fullpath')), 'Preprocessing');
            imagePath = fullfile(baseImagePath, selectedCategory, selectedFile);
        
            if isfile(imagePath)
                img = imread(imagePath);    
                app.Image.ImageSource = img;  % Shows image in uiimage
            else
                uialert(app.UIFigure, 'Image file not found.', 'Error');
            end
        end

        % Selection changed function: CategoryButtonGroup
        function CategoryButtonGroupSelectionChanged(app, event)
            
            selectedButton = app.CategoryButtonGroup.SelectedObject.Text;
            app.CurrentCategory = selectedButton;
            
            %baseImagePath = 'C:\IPPR\matlab\Preprocessing';  % example
            baseImagePath = fullfile(fileparts(mfilename('fullpath')), 'Preprocessing');
            categoryFolder = fullfile(baseImagePath, selectedButton);
            
            disp(['Looking in: ', categoryFolder]);  % Debug print


            if isfolder(categoryFolder)
                imageFiles =    [dir(fullfile(categoryFolder, '*.jpg')); ...
                                dir(fullfile(categoryFolder, '*.png'))];
                fileNames = {imageFiles.name};  % Extract file names
        
                if ~isempty(fileNames)
                    app.SampleDropDown.Items = fileNames;
                    app.SampleDropDown.Value = fileNames{1};  % Select first item by default
                    SampleDropDownValueChanged(app, []);

                    % Auto-preview first image
                    imagePath = fullfile(categoryFolder, fileNames{1});
                    img = imread(imagePath);
                    app.Image.ImageSource = img;
                else
                    app.SampleDropDown.Items = {'<No images found>'};
                    app.Image.ImageSource = [];  % Clear image
                end
            else
                app.SampleDropDown.Items = {'<Invalid folder>'};
                app.Image.ImageSource = [];  % Clear image
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Get the file path for locating images
            pathToMLAPP = fileparts(mfilename('fullpath'));

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 907 515];
            app.UIFigure.Name = 'MATLAB App';

            % Create Image
            app.Image = uiimage(app.UIFigure);
            app.Image.Position = [42 39 393 393];
            app.Image.ImageSource = fullfile(pathToMLAPP, 'Boat', 'boat-AWR7120.jpg');

            % Create SampleDropDownLabel
            app.SampleDropDownLabel = uilabel(app.UIFigure);
            app.SampleDropDownLabel.HorizontalAlignment = 'right';
            app.SampleDropDownLabel.Position = [640 389 46 22];
            app.SampleDropDownLabel.Text = 'Sample';

            % Create AnalyseButton
            app.AnalyseButton = uibutton(app.UIFigure, 'push');
            app.AnalyseButton.ButtonPushedFcn = createCallbackFcn(app, @AnalyzeButtonPushed, true);
            app.AnalyseButton.Position = [641 314 233 23];
            app.AnalyseButton.Text = 'Analyse';

            % Create SampleDropDown
            app.SampleDropDown = uidropdown(app.UIFigure);
            app.SampleDropDown.Items = {'boat-TKS00114P.jpg'};
            app.SampleDropDown.ValueChangedFcn = createCallbackFcn(app, @SampleDropDownValueChanged, true);
            app.SampleDropDown.Position = [701 389 172 22];
            app.SampleDropDown.Value = 'boat-TKS00114P.jpg';

            % Create CategoryButtonGroup
            app.CategoryButtonGroup = uibuttongroup(app.UIFigure);
            app.CategoryButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @CategoryButtonGroupSelectionChanged, true);
            app.CategoryButtonGroup.Title = 'Category';
            app.CategoryButtonGroup.Position = [478 278 123 154];

            % Create LorryButton
            app.LorryButton = uitogglebutton(app.CategoryButtonGroup);
            app.LorryButton.Text = 'Lorry';
            app.LorryButton.Position = [12 36 100 23];

            % Create CarButton
            app.CarButton = uitogglebutton(app.CategoryButtonGroup);
            app.CarButton.Text = 'Car';
            app.CarButton.Position = [11 58 100 23];

            % Create BusButton
            app.BusButton = uitogglebutton(app.CategoryButtonGroup);
            app.BusButton.Text = 'Bus';
            app.BusButton.Position = [11 79 100 23];

            % Create BoatButton
            app.BoatButton = uitogglebutton(app.CategoryButtonGroup);
            app.BoatButton.Text = 'Boat';
            app.BoatButton.Position = [11 100 100 23];
            app.BoatButton.Value = true;

            % Create TaxiButton
            app.TaxiButton = uitogglebutton(app.CategoryButtonGroup);
            app.TaxiButton.Text = 'Taxi';
            app.TaxiButton.Position = [13 14 100 23];

            % Create LicensePlateRecognitionLPRandStateIdentificationSystemSISLabel
            app.LicensePlateRecognitionLPRandStateIdentificationSystemSISLabel = uilabel(app.UIFigure);
            app.LicensePlateRecognitionLPRandStateIdentificationSystemSISLabel.HorizontalAlignment = 'center';
            app.LicensePlateRecognitionLPRandStateIdentificationSystemSISLabel.FontSize = 18;
            app.LicensePlateRecognitionLPRandStateIdentificationSystemSISLabel.Position = [42 465 831 23];
            app.LicensePlateRecognitionLPRandStateIdentificationSystemSISLabel.Text = 'License Plate Recognition (LPR) and State Identification System (SIS)';

            % Create RecognisedCarPlateEditFieldLabel
            app.RecognisedCarPlateEditFieldLabel = uilabel(app.UIFigure);
            app.RecognisedCarPlateEditFieldLabel.Position = [478 224 122 22];
            app.RecognisedCarPlateEditFieldLabel.Text = 'Recognised Car Plate';

            % Create FirstCharacterEditFieldLabel
            app.FirstCharacterEditFieldLabel = uilabel(app.UIFigure);
            app.FirstCharacterEditFieldLabel.Position = [478 174 84 22];
            app.FirstCharacterEditFieldLabel.Text = 'First Character';

            % Create FirstCharacterEditField
            app.FirstCharacterEditField = uieditfield(app.UIFigure, 'text');
            app.FirstCharacterEditField.ValueChangedFcn = createCallbackFcn(app, @AnalyzeButtonPushed, true);
            app.FirstCharacterEditField.Editable = 'off';
            app.FirstCharacterEditField.Enable = 'off';
            app.FirstCharacterEditField.Position = [640 174 233 22];

            % Create VehicleStateCharacteisticsEditFieldLabel
            app.VehicleStateCharacteisticsEditFieldLabel = uilabel(app.UIFigure);
            app.VehicleStateCharacteisticsEditFieldLabel.Position = [478 120 154 22];
            app.VehicleStateCharacteisticsEditFieldLabel.Text = 'Vehicle State/Characteistics';

            % Create VehicleStateCharacteisticsEditField
            app.VehicleStateCharacteisticsEditField = uieditfield(app.UIFigure, 'text');
            app.VehicleStateCharacteisticsEditField.ValueChangedFcn = createCallbackFcn(app, @AnalyzeButtonPushed, true);
            app.VehicleStateCharacteisticsEditField.Editable = 'off';
            app.VehicleStateCharacteisticsEditField.Enable = 'off';
            app.VehicleStateCharacteisticsEditField.Position = [640 120 233 22];

            % Create RecognisedCarPlateEditField
            app.RecognisedCarPlateEditField = uieditfield(app.UIFigure, 'text');
            app.RecognisedCarPlateEditField.ValueChangedFcn = createCallbackFcn(app, @AnalyzeButtonPushed, true);
            app.RecognisedCarPlateEditField.Editable = 'off';
            app.RecognisedCarPlateEditField.Enable = 'off';
            app.RecognisedCarPlateEditField.Position = [640 224 233 22];

            % Create CreatedbyWongWeiFongTP065467IanGanJianHaoTP064373Label
            app.CreatedbyWongWeiFongTP065467IanGanJianHaoTP064373Label = uilabel(app.UIFigure);
            app.CreatedbyWongWeiFongTP065467IanGanJianHaoTP064373Label.Position = [478 39 395 33];
            app.CreatedbyWongWeiFongTP065467IanGanJianHaoTP064373Label.Text = 'Created by Wong Wei Fong (TP065467) & Ian Gan Jian Hao (TP064373)';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = coding_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end