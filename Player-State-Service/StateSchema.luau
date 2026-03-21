local StateSchema = {}

export type Schema = {
    SchemaName: string,
    Type: "number" | "string" | "table" | "boolean",
    WriteableBy: {string},
}

function StateSchema.RegisterSchema(SchemaNameI: string, TypeI: "number" | "string" | "table" | "boolean", WriteableByI: {string}): Schema
    return {
        SchemaName = SchemaNameI,
        Type = TypeI,
        WriteableBy = WriteableByI,
    }
end

-- Register Schema's here
StateSchema.RegisteredSchemas = {

}

return StateSchema