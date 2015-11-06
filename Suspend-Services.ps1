# get our server list
$servers = @('server01', 'server02')
# these are the services we're concerned with
$services = @('process1', 'process2')

# returns the status of a given service on a server
function Get-ServiceStatus ($server, $service) {
    $status = $null
    if (-not ($status = (Get-Service -ComputerName $server -Name $service -ErrorAction SilentlyContinue).Status)) { 
                $status = 'Not Found'
    }
    return $status
}

# get the status of the services
function Invoke-ServicesCommand ($type) {
    $serviceList = @()
    foreach ($server in $servers) {
        if (Test-Connection -ComputerName $server -Count 1 -Quiet) {
            foreach ($service in $services) {
                $serviceObject = New-Object PSObject -Property @{
                    Server = $server
                    Service = $service
                    Status = Get-ServiceStatus $server $service
                }

                switch ($type) {
                    # get the status of the services
                    get { }

                    # start the services and set the startup to Automatic
                    start {
                        if ($serviceObject.Status -eq 'Not Found') { Continue }
                        Get-Service -ComputerName $server -Name $service | Set-Service -Status Running -StartupType Automatic
                        $serviceObject.Status = Get-ServiceStatus $server $service
                    }

                    # stop and disable the services
                    stop {
                        if ($serviceObject.Status -eq 'Not Found') { Continue }
                        Get-Service -ComputerName $server -Name $service | Set-Service -Status Stopped -StartupType Disabled
                        $serviceObject.Status = Get-ServiceStatus $server $service
                    }
                }
                $serviceList += $serviceObject
            }
        } else {
            $serviceList += New-Object PSObject -Property @{
                Server = $server
                Service = '-'
                Status = 'Offline'
            }
        }

    }
    $serviceList | Sort-Object Server | Select-Object Server, Service, Status | Format-Table -AutoSize
}

# give the user an interface to run options
function Prompt {
    $title = "Services Utility"
    $message = "What do you want to do?"
    $get = New-Object System.Management.Automation.Host.ChoiceDescription "&Get", "Gets the status of the services."
    $start = New-Object System.Management.Automation.Host.ChoiceDescription "&Start", "Starts the services and sets the startup type to automatic."
    $kill = New-Object System.Management.Automation.Host.ChoiceDescription "&Kill", "Stops and disables the services."
    $exit = New-Object System.Management.Automation.Host.ChoiceDescription "&Exit", "Exits this utility."
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($get, $start, $kill, $exit)
    $result = $host.ui.PromptForChoice($title, $message, $options, 0)

    switch ($result) {
        0 {'Getting services...'; Invoke-ServicesCommand get; break}
        1 {'Starting services...'; Invoke-ServicesCommand start; break}
        2 {'Stopping Services...'; Invoke-ServicesCommand stop; break}
        3 {'Exiting...'; exit}
    }

    Prompt
}

Prompt
