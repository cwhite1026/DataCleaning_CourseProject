#This script reads in the various data sets from the Samsung accelerometer
#data set and merges them into one tidy data set.  This script must be run
#from the main folder that contains the raw data.

#Pull in some libraries
library(dplyr, tidyr, data.table)

#--------------------------------#
#- Get the names of the columns -#
#--------------------------------#
#Pull in the file that contains the column names
list_of_labels <- read.table("features.txt", stringsAsFactors = FALSE,
                             col.names = c("index", "feature"))
#Snag just the column numbers and names that we want: means and standard
#deviations
label_contains_mean <- grepl("mean()", list_of_labels$feature, fixed=TRUE)
mean_colnums <- which(label_contains_mean)
label_contains_std <- grepl("std()", list_of_labels$feature, fixed=TRUE)
std_colnums <- which(label_contains_std)
colnums_we_want <- sort(c(mean_colnums, std_colnums))
colnames_we_want <- list_of_labels$feature[colnums_we_want]
colnames_we_want <- sapply(colnames_we_want, gsub, pattern="()", 
                           replacement="", fixed=TRUE, USE.NAMES = FALSE)
colnames_we_want <- sapply(colnames_we_want, gsub, pattern="-", 
                           replacement="_", fixed=TRUE, USE.NAMES = FALSE)

#-------------------------#
#- Pull in the data sets -#
#-------------------------#
training_set_readings <- fread("train/X_train.txt", 
                               stringsAsFactors = FALSE,
                               select = colnums_we_want,
                               col.names = colnames_we_want)
training_set_activities <- fread("train/y_train.txt", 
                                 col.names = c("activity_code"))
training_subjects <- fread("train/subject_train.txt", 
                           col.names = c("subject_number"))
test_set_readings <- fread("test/X_test.txt", 
                           stringsAsFactors = FALSE,
                           select = colnums_we_want,
                           col.names = colnames_we_want)
test_set_activities <- fread("test/y_test.txt",
                             col.names = c("activity_code"))
test_subjects <- fread("test/subject_test.txt", 
                       col.names = c("subject_number"))
activity_labels <- read.table("activity_labels.txt", 
                              col.names = c("code", "activity"),
                              stringsAsFactors = FALSE)

#----------------------#
#- Combine the tables -#
#----------------------#
#Make an activity column that has the description of the activity instead
#of the number and get rid of the column with the code
test_set_activities[,activity:=activity_labels$activity[activity_code]]
test_set_activities <- select(test_set_activities, -activity_code)
training_set_activities[,activity:=activity_labels$activity[activity_code]]
training_set_activities <- select(training_set_activities, -activity_code)

#Put the IDs and activities into the main sets and do some cleanup
test_set <- bind_cols(test_subjects, test_set_activities, test_set_readings)
rm("test_set_readings", "test_set_activities", "test_subjects")
training_set <- bind_cols(training_subjects, training_set_activities, 
                      training_set_readings)
rm("training_set_readings", "training_set_activities","training_subjects")

#Paste the two bunches together and arrange by subject number
data_set <- bind_rows(test_set, training_set)
rm("test_set", "training_set")
data_set <- arrange(data_set, subject_number)

#------------------------------------------------------#
#- Make a separate data table with summary statistics -#
#------------------------------------------------------#
#I'm really sorry you have to figure this section out, so I'm going to 
#comment it excessively.  I relied heavily on the stack_overflow thread
# http://stackoverflow.com/questions/26003574/r-dplyr-mutate-use-dynamic-variable-names
#to figure this bit out

#Start a summary table.  We don't have anything yet, so just put in the
#identifiers we care about
summary_table <- select(data_set, subject_number, activity)
#Tell the data set to perform group operations by unique combinations
#of subject_number and activity
data_set <- group_by(data_set, subject_number, activity)

#Loop through all the columns that aren't the subject or the activity
for (name in colnames_we_want){
    #Make a variable that contains what I want the new column to be called
    new_colname <- paste0("average_",name)
    #This chunk adds a column to the summary table through various dplyr
    #acrobatics, relying heavily on the SE versions of the functions
    #(denoted by the _ at the end of the function name)
    summary_table <- data_set %>%  #Feed the data set in...
        #Add a column that is called "average_"<colname> with the 
        #averages by group (the group_by ensures that it does mean by group)
        mutate_(.dots = setNames(paste0("mean(",name,")"), new_colname)) %>%
        #Ungroup that guy so we can pull out the new column- if you don't, 
        #it drags the two group ids with it.  Note that this is temporary
        ungroup %>%
        #Pull out just the new column
        select_(new_colname) %>%
        #and bind it to the summary table.  The x= means that it'll go in
        #on the right.
        bind_cols(x=summary_table)
}

#Now we have a bunch of duplicate rows with the same info- collapse it to
#just unique rows.
summary_table <- unique(summary_table)

#Write out the summary table
write.table(summary_table, "average_measures_for_all_subjects.txt", row.name=FALSE)

