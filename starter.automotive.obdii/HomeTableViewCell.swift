//
//  HomeTableViewCell.swift
//  starter.automotive.obdii
//
//  Created by Eliad Moosavi on 2016-11-30.
//  Copyright © 2016 IBM. All rights reserved.
//

import UIKit

class HomeTableViewCell: UITableViewCell {
    @IBOutlet weak var propTitle: UILabel!
    @IBOutlet weak var propValue: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
