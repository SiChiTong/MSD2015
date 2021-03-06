%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Author: Nestor Hernandez Rodriguez
% Project: Robotic Referee Drone
% Date: March 2016
% Technical University of Eindhoven
% Mechatronic Systems Design PDEng trainee
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [OutOfPitchFlag, pixelDistance] = refereeingOutOfPitch(ballPosition,selectedLines,numOutOfBoundLines,frameProperties,droneInPitch,thetaCamX,height,worldModelOuterLines)

% This function updates the OutOfPitchFlag ('0'- inside the pitch, '1'-
% out of the pitch or '-1' not known)
% 
% Inputs:
% ballPosition - X and Y coordinates of the ball in pixels within the current frame
% 
% selectedLines - Matrix containing the selected lines points, theta and
% rho [x1_vector y1_vector x2_vector y2_vector theta_vector rho_vector]
% 
% numOutOfBoundLines - Integer that contains the number of outer lines that the frame should contain
%
% frameProperties - [height width] Size of the frame used after pre-process
%
% dronInPitch - Flag '1' - Inside; '0' outside
%
% worldModelOuterLines - Matrix 4x5 containing ID, InFrameFlag, SideOrGoal
% line identification, rho and theta for the 4 outer lines.
%
% Outputs:
% OutOfPitchFlag - flag indicating the stating if the ball is inside or
% outside of the pitch
%
% pixelDistance - pixel to meters conversion factor
%
% NOTE:
% The position of the drone within the frame it is assumed to be in the
% center of the frame using a top view camera with a pitch angle of 
% pi/2 rad (completely vertical)

%% Categorize the lines provided by the World Model into side or goal lines
auxWMSideLines=worldModelOuterLines(worldModelOuterLines(:,2)==1,:); % Filter by the InFrameFlag equal to '1'
auxWMSideLines1=auxWMSideLines(auxWMSideLines(:,3)==1,:); % Filter by the SideOrGoal flag equal to '1' - Side
auxWMGoalLines=worldModelOuterLines(worldModelOuterLines(:,2)==1,:); % Filter by the InFrameFlag equal to '1'
auxWMGoalLines1=auxWMGoalLines(auxWMGoalLines(:,3)==2,:); % Filter by the SideOrGoal flag equal to '2' - Goal

%% Take theta references to filter correct candidates
if ~isempty(auxWMSideLines1)
    mThetaSideReference=auxWMSideLines1(1,5);
else
    mThetaSideReference=-999; % Predefined theta reference when there is no candidate
end

if ~isempty(auxWMGoalLines1)
    mThetaGoalReference=auxWMGoalLines1(1,5);
else
    mThetaGoalReference=-999; % Predefined theta reference when there is no candidate
end

mThetaReferences=[mThetaSideReference mThetaGoalReference];

sizeSelectedLines=size(selectedLines);
rhoDistanceTH=0.4; % rho threshold in meters
thetaTH=pi/6; % theta threshold in radians 

%% Calculate drone position in the frame
dronePosition=[frameProperties(2)/2 frameProperties(1)/2];

%% Calculate pixel to meters conversion factor
pixelDistance = (height*tan(thetaCamX/2))/(frameProperties(2)/2);

%% Create mask and initialize variables for filtering outer lines
outOfBoundsDetector=zeros(sizeSelectedLines(1),1); 

auxCntSide=0;
auxCntGoal=0;
auxCnt=0;

%% If there are no out of bounds line detected then give the result
if numOutOfBoundLines == 0
    if ballPosition == [-100 -100] % Predefined ball position given when no ball is found 
        OutOfPitchFlag = -1;
    elseif droneInPitch
        OutOfPitchFlag = 0;
    else
        OutOfPitchFlag = -1;
    end        
else % Calculate mask based on theta comparison
    for i=1:sizeSelectedLines(1)

          mTheta=selectedLines(i,5)*pi/180;
          if mTheta>0
            if abs(mTheta)<mThetaReferences(1)+thetaTH && abs(mTheta)>mThetaReferences(1)-thetaTH
                auxCntSide=auxCntSide+1;
                outOfBoundsDetector(i)=1; % '1' for a correct side line matching
            elseif abs(mTheta)<mThetaReferences(2)+thetaTH && abs(mTheta)>mThetaReferences(2)-thetaTH
                    auxCntGoal=auxCntGoal+1;
                    outOfBoundsDetector(i)=2; % '2' for a correct goal line matching
				else
                outOfBoundsDetector(i)=0; % '0' for no matching                    
            end
          else
            if mTheta>mThetaReferences(1)-thetaTH && mTheta<mThetaReferences(1)+thetaTH
                auxCntSide=auxCntSide+1;
                outOfBoundsDetector(i)=1; % '1' for a correct side line matching
            elseif mTheta>mThetaReferences(2)-thetaTH && mTheta<mThetaReferences(2)+thetaTH
                    auxCntGoal=auxCntGoal+1;
                    outOfBoundsDetector(i)=2; % '2' for a correct goal line matching
				else
                outOfBoundsDetector(i)=0; % '0' for no matching                    
            end
          end
   end 

    %% Filter possible parallel lines selected as outer lines based on rho provided as input
    selectedFilteredLines=zeros(2,6); % Predefined as 'First row' for possible 'side line' and 'Second row' for possible 'goal line'
    auxSideLines=selectedLines(outOfBoundsDetector==1,:); % Filter selected lines with mask to get side lines detected
    sizeAuxSideLines=size(auxSideLines);
    auxGoalLines=selectedLines(outOfBoundsDetector==2,:); % Filter selected lines with mask to get goal lines detected
    sizeAuxGoalLines=size(auxGoalLines);

    if sizeAuxSideLines(1)>0 % If filtered selected side lines is not empty
        for j=1:sizeAuxSideLines(1)
            if ~isempty(auxWMSideLines1) % If World Model filtered lines is not empty
                if abs(auxSideLines(j,6)*pixelDistance)>auxWMSideLines1(1,4)-rhoDistanceTH && abs(auxSideLines(j,6)*pixelDistance)<auxWMSideLines1(1,4)+rhoDistanceTH % Filter using rho
                    selectedFilteredLines(1,:)=auxSideLines(j,:); % Matching side line stored in the first row
                    auxCntSide=1;
                end
            end
        end
    else
       auxCntSide=0; % No side lines can be matched
    end

    if sizeAuxGoalLines(1)>0
        for j=1:sizeAuxGoalLines(1)
            if ~isempty(auxWMGoalLines1)
                if abs(auxGoalLines(j,6)*pixelDistance)>auxWMGoalLines1(1,4)-rhoDistanceTH && abs(auxGoalLines(j,6)*pixelDistance)<auxWMGoalLines1(1,4)+rhoDistanceTH
                    selectedFilteredLines(2,:)=auxGoalLines(j,:); % Matching goal line stored in the second row
                    auxCntGoal=1;
                end
            end

        end 
    else
       auxCntGoal=0; % No goal lines can be matched
    end

    auxCnt=auxCntSide+auxCntGoal; % Total number of lines matched. It can only be '0', '1' or '2' (either you see no lines, 1 side or 1 goal line or a corner that contains both, 1 side line and 1 goal line), this is based on the FOV of the camera and the height ranged assumed

    %% Calculate relative position for ball and drone respect to the filtered outer lines 
    % The process of calculating the relative position is defined as follows:
    %   1. Creating different areas of the frame defined with the intersection of the outer lines
    %   2. Filling in a binary output stating if the object (drone or ball)
    %      is above or below the lines with a '1' or '0' respectively

    %% Calculate Relative Ball Position
    syms x_v2;
    sizeFilteredLines=size(selectedFilteredLines);
    relativeBallPosition=zeros(sizeFilteredLines(1),1);
    relativeDronePosition=zeros(sizeFilteredLines(1),1);

    for k=1:sizeFilteredLines(1) % The size of the filtered selected lines

        a_p=(selectedFilteredLines(k,4)-selectedFilteredLines(k,2))/(selectedFilteredLines(k,3)-selectedFilteredLines(k,1));
        if a_p>20 % Filtering completely vertical slopes (inf. slope) to a slope of ~20
            a_p=20;
        elseif a_p<-20
            a_p=-20;
        end
        b_p=(-selectedFilteredLines(k,1)*a_p+selectedFilteredLines(k,2));    
        Fline=symfun(a_p*x_v2+b_p,x_v2);

        % Check position with respect to the lines

        if ballPosition(2)>Fline(ballPosition(1))
            relativeBallPosition(k)= 1; % True (x grows -> right; y grows -> down)
        else
            relativeBallPosition(k)= 0; % False      
        end
    end

    %% Calculate Relative Drone Position

    for k=1:sizeFilteredLines(1) % The size of the filtered selected lines

        a_p=(selectedFilteredLines(k,4)-selectedFilteredLines(k,2))/(selectedFilteredLines(k,3)-selectedFilteredLines(k,1));
        if a_p>20 % Filtering completely vertical slope
            a_p=20;
        elseif a_p<-20
            a_p=-20;
        end
        b_p=(-selectedFilteredLines(k,1)*a_p+selectedFilteredLines(k,2));    
        Fline=symfun(a_p*x_v2+b_p,x_v2);

        % Check position with respect to the lines

        if dronePosition(2)>Fline(dronePosition(1))
            relativeDronePosition(k)= 1; % True (x grows -> right; y grows -> down)
        else
            relativeDronePosition(k)= 0; % False      
        end
    end

    %% Update OutOfBounds flag (Refereeing)

    switch numOutOfBoundLines

        case 2 % Two outer lines can be found (1 Side line and 1 Goal line -> Corner)

            if auxCnt==2 % If this does not match then the refereeing is not done                

               if droneInPitch==1 % If drone is in pitch

                   if relativeDronePosition(1)==relativeBallPosition(1) && relativeDronePosition(2)==relativeBallPosition(2) % Compare to the 2 outer lines

                       OutOfPitchFlag=0; % Not out of pitch

                   else

                       OutOfPitchFlag=1; % Out of pitch
                   end
               else % If drone is not in pitch
                   OutOfPitchFlag=-1; % Not known
               end

            else
                OutOfPitchFlag=-1; % Not known

            end


        case 1 % One outer line can be found

            if auxCnt==1
                if auxCntSide==1 % Compare with the side line
                   if droneInPitch==1 % If drone is in pitch

                       if relativeDronePosition(1)==relativeBallPosition(1) % Compare to the only outer line (side)

                           OutOfPitchFlag=0; % Not out of pitch

                       else

                           OutOfPitchFlag=1; % Out of pitch
                       end
                   else % If drone is not in pitch
                       OutOfPitchFlag=-1; % Not known
                   end
                else % Compare with the goal line
                    if droneInPitch==1 % If drone is in pitch

                       if relativeDronePosition(2)==relativeBallPosition(2) % Compare to the only outer line (goal)

                           OutOfPitchFlag=0; % Not out of pitch

                       else

                           OutOfPitchFlag=1; % Out of pitch
                       end
                    else % If drone is not in pitch
                        OutOfPitchFlag=-1; % Not known  
                    end
                end

            else
                OutOfPitchFlag=-1; % Not known

            end

        otherwise % Refereeing is not done

            OutOfPitchFlag=-1; % Not known

    end
end


    
    