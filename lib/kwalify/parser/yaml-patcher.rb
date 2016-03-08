class Kwalify::Yaml::Parser < Kwalify::BaseParser
  def parse_block_value(level, rule, path, uniq_table, container)
    skip_spaces_and_comments
    ## nil
    return nil if @column < level || (@column == level && !match?(/-\s+/)) || eos?
    ## anchor and alias
    name = nil
    if scan(/\&([-\w]+)/)
      name = parse_anchor(rule, path, uniq_table, container)
    elsif scan(/\*([-\w]+)/)
      return parse_alias(rule, path, uniq_table, container)
    end
    ## type
    skip_spaces_and_comments if scan(/!!?\w+/)
    ## sequence
    if match?(/-\s+/)
      if rule && !rule.sequence
        # _validate_error("sequence is not expected.", path)
        rule = nil
      end
      seq = create_sequence(rule, @linenum, @column)
      @anchors[name] = seq if name
      parse_block_seq(seq, rule, path, uniq_table)
      return seq
    end
    ## mapping
    if match?(MAPKEY_PATTERN)
      if rule && !rule.mapping
        # _validate_error("mapping is not expected.", path)
        rule = nil
      end
      map = create_mapping(rule, @linenum, @column)
      @anchors[name] = map if name
      parse_block_map(map, rule, path, uniq_table)
      return map
    end
    ## sequence (flow-style)
    if match?(/\[/)
      if rule && !rule.sequence
        # _validate_error("sequence is not expected.", path)
        rule = nil
      end
      seq = create_sequence(rule, @linenum, @column)
      @anchors[name] = seq if name
      parse_flow_seq(seq, rule, path, uniq_table)
      return seq
    end
    ## mapping (flow-style)
    if match?(/\{/)
      if rule && !rule.mapping
        # _validate_error("mapping is not expected.", path)
        rule = nil
      end
      map = create_mapping(rule, @linenum, @column)
      @anchors[name] = map if name
      parse_flow_map(map, rule, path, uniq_table)
      return map
    end
    ## block text
    if match?(/[|>]/)
      text = parse_block_text(level, rule, path, uniq_table)
      @anchors[name] = text if name
      return text
    end
    ## scalar
    scalar = parse_block_scalar(rule, path, uniq_table)
    @anchors[name] = scalar if name
    scalar
  end
end
