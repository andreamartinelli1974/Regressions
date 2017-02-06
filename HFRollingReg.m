classdef HFRollingReg < HFRegression
    % subclass of HFRegression to perform regressions on a rolling
    % timeframe 
    
    % Functions:
    
    % RollingReg(obj) = rolling regression on monthly data. Thake the
    % property RollingPeriod as number of months for the rolling window and
    % build a matrix with the betas for any step in time. The result of
    % the last regression are stored in RegResult. The regression stats are
    % stored in RegTests 
    
    % ConRollReg(obj,LogicalMTX) = conditional rolling regression: use a
    % logical matrix to chose wich regressor include. For any step the
    % regression on any row of the logical matrix and chose the one with
    % minimum MSE.
    % Betas store the beta of any step and RegTests the different 
    % regression statistics
    
    % MTXRollReg(obj,LogicalMTX) = create a cube of betas: for any
    % timestep, for any row of the LogicalMTX calculate the betas on the
    % regressors. in this case there is no calculation nor storing of the
    % regression quality tests. this function is used to implement the
    % Model Combination Approach
    
    % GetRolling: set Output = RollingPeriod
    
    % GetBetas: set Output = Betas
    
    
    methods
        % constructor
        function obj = HFRollingReg(params)
            
            obj = obj@HFRegression(params);
            obj.RollingPeriod = params.rollingperiod;
            
        end
        
        function RollingReg(obj)
            
            if size(obj.TableRet,1)-obj.RollingPeriod<=0
                    ME=MException('myComponent:dateError','la finestra di rolling é troppo lunga',obj.HFund.Name);
                    throw(ME)
            end
            
            obj.MtxOfRegressors = ones(1,size(obj.TableRet,2)-2);    
                
            steps=size(obj.TableRet,1)-obj.RollingPeriod+1;
            % steps=number of total common data between dependent var and
            % regressors minus the rolling window
            obj.Betas=zeros(steps,size(obj.TableRet,2));
            
            for i=1:steps
                %sets the table to perform the regression on
                rollingTable=obj.TableRet(i:obj.RollingPeriod+i-1,2:end);
                
                % this is the regression
                obj.RegResult=fitlm(rollingTable);
                
                trackdate=obj.TableRet(obj.RollingPeriod+i-1,1).date;
                coefficients=obj.RegResult.Coefficients.Estimate';
                
                % writes the betas matrix
                obj.Betas(i,:)=[trackdate,coefficients];
                
                % creates and fills the regression statistic structure
                RT=obj.RegressionTest(obj.RegResult);
                stats.OrdRS(i)=RT.OrdRSquared;
                stats.AdjRS(i)=RT.AdjRSquared;
                stats.MSE(i)=RT.MSE;
                stats.FTest(i)=RT.FTest;
                stats.PValue(i)=RT.PValue;
            end
            
            obj.RegTests=stats;
            k=find(abs(obj.Betas)<1e-9);
            obj.Betas(k)=0;
            obj.Betas=array2table(obj.Betas,'VariableNames',['Dates','Intercept',{obj.TableRet.Properties.VariableNames{2:end-1}}]);
            
        end
       
        function ConRollReg(obj,LogicalMTX)
            
            if size(obj.TableRet,1)-obj.RollingPeriod<=0
                    ME=MException('myComponent:dateError','la finestra di rolling é troppo lunga',obj.HFund.Name);
                    throw(ME)
            end
            %obj.TableRet(1,end)
            obj.MtxOfRegressors = LogicalMTX;   
                
            steps=size(obj.TableRet,1)-obj.RollingPeriod+1;
            % steps=number of total common data between dependent var and
            % regressors minus the rolling window
            obj.Betas=zeros(steps,size(obj.TableRet,2));
            
            for j=1:steps %cycle on dates
              
                testmin=100;
                
                % sets the table to perform the regression on
                rollingTable=obj.TableRet(j:obj.RollingPeriod+j-1,2:end);
                
                for i=1:size(obj.MtxOfRegressors,1) %cycle on logical matrix rows
                    
                    % choses the regressors according to the logical matrix
                    % (row by row)
                    colmns = [find(obj.MtxOfRegressors(i,:)),size(rollingTable,2)];
                    selectedTable = rollingTable(:,colmns);
                    
                    % this is the regression
                    temporary = fitlm(selectedTable);
                    
                    % creates and fills the regression statistic structure
                    RT=obj.RegressionTest(temporary);
                    
                    % Checks for the goodness of the regresson compared to
                    % the previous best regression in terms of MSE
                    if RT.MSE<testmin
                        obj.RegResult = temporary;
                        RT=obj.RegressionTest(temporary);
                        stats.OrdRS(j)=RT.OrdRSquared;
                        stats.AdjRS(j)=RT.AdjRSquared;
                        stats.MSE(j)=RT.MSE;
                        stats.FTest(j)=RT.FTest;
                        stats.PValue(j)=RT.PValue;
                        testmin=stats.MSE;
                        obj.Betas(j,:)=0;
                        
%                         [obj.TableRet(1,end).Properties.VariableNames,j,i]
%                         [size(obj.TableRet.date),obj.RollingPeriod+j-1,obj.RollingPeriod+i-1,obj.TableRet(obj.RollingPeriod+j-1,1).date]
                        trackdate=obj.TableRet(obj.RollingPeriod+j-1,1).date;
                        coefficients=obj.RegResult.Coefficients.Estimate';
                        
                        % writes the betas matrix
                        obj.Betas(j,[1,2,colmns(1:end-1)+2])=[trackdate,coefficients];
                        
                    end
                    
                end
            end
            
            obj.RegTests = stats;
            k=find(abs(obj.Betas)<1e-9);
            obj.Betas(k)=0;
            obj.Betas=array2table(obj.Betas,'VariableNames',['Dates','Intercept',{obj.TableRet.Properties.VariableNames{2:end-1}}]);
            
        end
        
        function MTXRollReg(obj,LogicalMTX)
            
            if size(obj.TableRet,1)-obj.RollingPeriod<=0
                    ME=MException('myComponent:dateError','la2 finestra di rolling é troppo lunga',obj.HFund.Name);
                    throw(ME)
            end
            
            obj.MtxOfRegressors = LogicalMTX;   
            
            % steps=number of total common data between dependent var and
            % regressors minus the rolling window
            steps=size(obj.TableRet,1)-obj.RollingPeriod+1;
            obj.Betas=zeros(steps,size(obj.TableRet,2),size(obj.MtxOfRegressors,1));
            
            for j=1:steps
                
                testmin=100;
                
                % sets the table to perform the regression on
                rollingTable=obj.TableRet(j:obj.RollingPeriod+j-1,2:end);
                
                for i=1:size(obj.MtxOfRegressors,1)
                    
                    % choses the regressors according to the logical matrix
                    % (row by row)
                    colmns = [find(obj.MtxOfRegressors(i,:)),size(rollingTable,2)];
                    selectedTable = rollingTable(:,colmns);
                    
                    % this is the regression
                    temporary = fitlm(selectedTable);
                    
                    trackdate=obj.TableRet(obj.RollingPeriod+i-1,1).date;
                    coefficients=temporary.Coefficients.Estimate';
                    k=find(abs(coefficients)<1e-9);
                    coefficients(k)=0;
                    
                    obj.Betas(j,:,i)=0;
                    
                    % writes the betas matrix
                    obj.Betas(j,[1,2,colmns(1:end-1)+2],i) = [trackdate,coefficients];
                end
            end
            
        end
        
        function GetRolling(obj)  
            obj.Output=obj.RollingPeriod;        
        end
        
        function GetBetas(obj)
            obj.Output=obj.Betas;        
        end
    end
    
    
    
end