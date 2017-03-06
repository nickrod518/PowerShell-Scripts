Offices.csv
This file contains all office drive mapping entries. One unique entry is "<Remove All>", the script treats this entry special in that when selected it removes all currently mapped network drives. Here is a description of each column in the file:
Location - friendly name of the location of the drive mapping as it will appear in the drive mapping utility.
Type - 3 acceptable keywords here, Local is used for mappings that should only apply when using Map Drives Utility, Citrix is used for mappings that should only apply when the utility is invoked from a Citrix GPO, Both is used for mappings that should apply in both local and Citrix sessions.
DriveLetter - the drive letter to use in the mapping.
DrivePath - the network path to use in the mapping.

Translations.csv
This file is used only in the context of a Citrix GPO. It uses the groups that the user is a member, groups they aren't a member of, the name of the user, and the computer the user is logged into, to get the name of a location that matches a location in the Offices.csv file and map those drives. The user must meet the criteria of all columns. Each column supports comma separated entries. Here is a description of each column in the file:
Location - location name to use in the Offices.csv file.
GroupName - name of the group the user must be a member of.
NotGroupName - name of the group the user must not be a member of.
UserName - the user must have this name.
ComputerName - the user must be logged into this computer.