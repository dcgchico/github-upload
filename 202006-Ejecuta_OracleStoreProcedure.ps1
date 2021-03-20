# Parameters webhooks
Param
(
    # Get webhook data
    [Parameter(Mandatory=$False,Position=1)]
    [object] $WebhookData
)

Add-Type -AssemblyName System.Data.OracleClient

$resultado = $null
$mensaje = $null
$parametros = $null

if ($WebhookData) {
    
    # Retrieve parametros from Webhook request body
    $parametros = (ConvertFrom-Json -InputObject $WebhookData.RequestBody)

    $conexion = $parametros.conexion
    $procedimiento = $parametros.procedimiento
    $usuario = $parametros.usuario
    $pwd = $parametros.pwd

    if([string]::IsNullOrEmpty($conexion) -or [string]::IsNullOrEmpty($procedimiento) -or [string]::IsNullOrEmpty($usuario) -or [string]::IsNullOrEmpty($pwd)){
        Write-Error "Falta algún parámetro"
        $resultado = 0
        $mensaje = "Falta algún parámetro"
    }
    else{

        $connection_string = "User Id=$usuario;Password=$pwd;Data Source=$conexion"

        try{
            $con = New-Object System.Data.OracleClient.OracleConnection($connection_string)

            $con.Open()

            $cmd = $con.CreateCommand()
            $cmd.CommandType = [System.Data.CommandType]::StoredProcedure
            $cmd.CommandText = $procedimiento
            $resultado = $cmd.ExecuteNonQuery() 
            $mensaje = "Llamada realizada"
        } 
        catch 
        {
            Write-Error (“Database Exception: {0}`n{1}” -f $con.ConnectionString, $_.Exception.ToString())
            $resultado = 0
            $mensaje = $_.Exception.ToString()
        } 
        finally
        {
            if ($con.State -eq ‘Open’) 
            { 
                $con.close() 
            }
        }
    }

}
else {
    Write-Error "El runbook se debe ejecutar desde un webhook"
}

# Read and store the callBackUri which is only provided by the Webhook activity
If ($parametros.callBackUri)
{
    $callBackUri = $parametros.callBackUri
}
$body = [ordered]@{
    output = @{
        Resultado = $resultado
        Mensaje = $mensaje
    }
}
Write-Output $body.output
If ($callBackUri)
{
    Write-Output $callBackUri
    $bodyJson = $body | ConvertTo-Json
 
    # Call back with error message in body and a JSON contenttype
    Invoke-WebRequest -Uri $callBackUri -Method Post -Body $bodyJson -ContentType "application/json" -UseBasicParsing
}