@{
    # Rules excluded for this project:
    #
    # PSAvoidUsingWriteHost      -- CLI tools and launchers intentionally use Write-Host for coloured output.
    # PSReviewUnusedParameter    -- Parameters can be used via dynamic dispatch or splatting.
    # PSAvoidGlobalVars          -- Menu scripts share state via module-level globals by design.
    # PSUseShouldProcessForStateChangingFunctions -- Admin tools and UI helpers don't need ShouldProcess.
    # PSAvoidUsingCmdletAliases  -- External Linux commands (uptime, uname, lscpu, etc.) are called via
    #                               the & operator; they are not PowerShell aliases.
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',
        'PSReviewUnusedParameter',
        'PSAvoidGlobalVars',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSAvoidUsingCmdletAliases'
    )

    # PSUseCompatibleCmdlets: flag cmdlets removed in PowerShell 7 (e.g. Get-EventLog, Get-WmiObject).
    # Targets the PS7 Windows and Linux profiles so cross-platform gaps are caught.
    Rules = @{
        PSUseCompatibleCmdlets = @{
            compatibility = @(
                'core-7.2.0-windows',
                'core-7.2.0-linux'
            )
        }
    }
}
