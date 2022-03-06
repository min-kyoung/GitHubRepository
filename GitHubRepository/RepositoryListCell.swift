//
//  RepositoryListCell.swift
//  GitHubRepository
//
//  Created by 노민경 on 2022/03/05.
//

import SnapKit
import UIKit

class RepositoryListCell: UITableViewCell {
    var repository: String?
    
    let nameLabel = UILabel()
    let descriptionLabel = UILabel()
    let startImageView = UIImageView()
    let starLabel = UILabel()
    let languageLabel = UILabel()
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        [
            nameLabel, descriptionLabel,
            startImageView, starLabel, languageLabel
        ].forEach {
            contentView.addSubview($0)
        }
        
        
        
    }
}
