/**
 * @description       : 
 * @author            : Akash Yadav
 * @group             : 
 * @last modified on  : 08-03-2025
 * @last modified by  : Akash Yadav
**/
public with sharing class ApplicantStatusBatchScheduler implements Schedulable{
    /**
    * @description 
    * @author Akash Yadav | 08-03-2025 
    * @param scheduleContext 
    **/
    public void execute(SchedulableContext scheduleContext) {
        Database.executeBatch(new MonitorJobApllicationBatch(), 200);
    }
}