function getLocalizedText(key)
  local data

  if save.lang == 'en' then
    data = en
  elseif save.lang == 'fr' then
    data = fr
  end

  return data and data[key] or key
end

function table.contains(tbl, query)
  for key, value in pairs(tbl) do
    if value == query then
      return key
    end
  end

  return false
end

function table.has_key(tbl, query)
  for key, _ in pairs(tbl) do
    if key == query then
      return true
    end
  end

  return false
end

function table.column(tbl, query, default_value)
  default_value = default_value or ''
  local values = {}
  for i = 1, #tbl do
    table.insert(values, tbl[i][query] or default_value)
  end
  return values
end
