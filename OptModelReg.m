classdef OptModelReg < handle
    % class to implement a baynesian approach to the optimization of a
    % multilinear regression for an hedge fund
   
    properties
        Input;  %input struct
        % the input struct must be composed in this way:
        % obj.Input.inputdates = params.inputdates;
        %       an array of dates in matlab numbers
        % obj.Input.inputarray = params.inputarray;
        %       a matrix containig the dependent variable in first colunm
        %       and the regressors in the othres 
        % obj.Input.inputnames = params.inputnames;
        %       a cell array with the names of the X and Ys
        % obj.Input.rollingperiod = params.rollingperiod;
        %       a single number indicating the rolling window leingh in
        %       terms of number of period (eg if the number is set as 60,
        %       could be 60 days in case the series are daily or 60
        %       weeks if the series are weekly
        RegressorsStrategies; %celle array with the strategy associated to any regressor
        ModelMTX; % Logical Matrix for the different models
        Rolling2; % rolling window for the baynesian optimisation
        ModelWeights; % matrix with the optimal weights for any models
        TableRet; % the table of returns of the regressors and the fund (last column)
        Betas; % cube of the betas. first column is the alpha.
        RollReg; % obj HFRollingReg. MAYBE UNNECESSARY
        Output; % obj HFRegresOPT: result of the optimized regression
        
       
    end
    
    methods
        
        function obj=OptModelReg(params) %Constructor
            obj.Input.inputdates = params.inputdates;
            obj.Input.inputarray = params.inputarray;
            obj.Input.inputnames = params.inputnames;
            obj.Input.rollingperiod = double(params.rollingperiod);
            obj.Rolling2=double(params.checkingperiod);
            obj.RegressorsStrategies=params.indexstrategies;
        end
        
        function OpRegression(obj)
            
            
            %create a HFRollingReg object 
            obj.RollReg=HFRollingReg(obj.Input);
            
            %get the Table with regressors and fund returns
            obj.RollReg.GetTableRet;
            obj.TableRet=obj.RollReg.Output;
            
            %create the logical matrix with the regressors to use in any
            %regression
            A=obj.RollReg.getMtxPredictors(obj,1,'strategy',obj.RegressorsStrategies);
            B=obj.RollReg.getMtxPredictors(obj,1,'correlation');
            lowcorrelregressors=find(B(end,:));
            obj.ModelMTX=A(:,lowcorrelregressors);
            
            % with the MTXRollReg method of the HFRollingReg object create
            % the array of the betas with 3 dimensions:
            % time,regressors and regressors strategy
            obj.RollReg.MTXRollReg(obj.ModelMTX);
            obj.RollReg.GetBetas;
            obj.Betas=obj.RollReg.Output;
            totalRollingPeriod=obj.Input.rollingperiod+obj.Rolling2;
            rolling=obj.Input.rollingperiod;
            
            if size(obj.TableRet,1)-(totalRollingPeriod)+1<=0
                    ME=MException('myComponent:dateError','la finestra di rolling é troppo lunga');
                    throw(ME)
            end
            
            %calculate B*ft, g this are the values for the t-student-like
            %distributions used to evaluate the goodness of any strategy
            %regression
            for k=1:size(obj.TableRet,1)-(totalRollingPeriod)+1 % cycle on rolling window
                for i=1:obj.Rolling2 % cycle on checking window
                    for j=1:size(obj.Betas,3) % cycle on regressors startegies
                        l=i+k-1;
                        
                        regressors1=table2array(obj.TableRet(rolling+l,2:end-1));
                        filter=find(obj.ModelMTX(j,:));
                        ft=regressors1(:,filter);
                        
                        regressors2=table2array(obj.TableRet(l:rolling+l-1,2:end-1));
                        Ft=regressors2(:,filter);
                        
                        g=1-ft/(Ft'*Ft+ft'*ft)*ft';
                        nu=rolling-size(ft,2);
                        Bft=table2array(obj.TableRet(l+rolling,2:end-1))*(obj.Betas(l,3:end,j))'+(obj.Betas(l,2,j));
                        h=(g*nu)/(table2array(obj.TableRet(l+rolling,end))-Bft)^2;
                        
                        % this is the score assigned to any strategy
                        % regression to weight the goodness of the
                        % estimated beta
                        logscore(i,j)=tpdf(sqrt(h)*(table2array(obj.TableRet(l+rolling,end))-Bft),nu)*sqrt(h);
                        lsnan=isnan(logscore);
                        lsnan=find(lsnan==1);
                        logscore(lsnan)=0;
                   
                    end
                end
                
                % optimization (using the logscore of any strategy
                % regression in the checking window)
                fun=@(x)-sum(log(logscore*x'));
                lb=zeros(1,size(obj.Betas,3));
                ub=ones(1,size(obj.Betas,3));
                constr=@norma;
                x0=ub/size(obj.Betas,3);
                
                %this is the optimization:
                obj.ModelWeights(k,:)=fmincon(fun,x0,[],[],[],[],lb,ub,constr);
                % a=[k,size(obj.TableRet,1)-(rolling+obj.Rolling2)+1];
            end
            
            % create the matrix of the betas weighted with the optimizer
            weightedBetas=zeros(size(obj.ModelWeights,1),size(obj.Betas,2)-1);
            for j=1:size(obj.Betas,3)   
                % weightedBetas=weightedBetas+obj.Betas(obj.Rolling2+1:end,2:end,j).*obj.ModelWeights(:,j);     
                
                rmatrix  = repmat(obj.ModelWeights(:,j),1,size(obj.Betas,2)-1);
                weightedBetas=weightedBetas+obj.Betas(obj.Rolling2+1:end,2:end,j).*rmatrix;
            end
            
            % cut the betas belows 10e-4 (to simplify the results)
            x=find(abs(weightedBetas)<=0.0001);
            weightedBetas(x)=0;
            betas=array2table([obj.TableRet(totalRollingPeriod:end,1).date,weightedBetas],'VariableNames',['Dates','Intercept',{obj.TableRet.Properties.VariableNames{2:end-1}}]);
            
            % create a HFOptReg object (a subclass of HFRegression to be
            % used by the HedgeFund object to build the backtest track
            % record
            inputs=obj.Input;
            inputs.rollingperiod=totalRollingPeriod;
            obj.Output=HFOptReg(inputs,betas,obj.TableRet);
            
        end
        
    end
    
end

%%*********************************************************************
%  SIMPLE NORM FUNCTION TO BE USED IN THE OPTIMIZATION
function [c,ceq]=norma(x)
    c=sum(x)-1;
    ceq=[];
end

%%*********************************************************************