classdef HFOptReg <Regression
    % Fake subclass to incorporate the result of the optimization performed
    % via the OptModelReg class and put this results into the HedgeFund
    % class
    
    % Functions:
    
    % just the constructor and the Gets functions for the 3 properties used
    % by the HedgeFund Class to create the backtest track record
    
    
    methods
        %constructor
        function obj=HFOptReg(inputs,betas,tableret)
            obj = obj@Regression(inputs);
            obj.RollingPeriod=inputs.rollingperiod;
            obj.Betas=betas;
            obj.TableRet=tableret;
        end
        
        %Get Functions
        function GetTableRet(obj)
            obj.Output = obj.TableRet;
        end
        function GetRolling(obj)
            obj.Output=obj.Rolling;
        end
        
        function GetBetas(obj)
            obj.Output=obj.Betas;
        end
    end
end